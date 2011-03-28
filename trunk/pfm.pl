#!/usr/bin/perl
#
##########################################################################
# @(#) pfm.pl 19990314-20020406 v1.61
#
# Name:        pfm.pl
# Version:     1.61
# Author:      Rene Uittenbogaard
# Date:        2002-04-06
# Usage:       pfm.pl [directory]
# Requires:    Term::ScreenColor
#              Term::Screen
#              Term::Cap
#              Term::ReadLine::Gnu
#              Term::ReadLine
#              Config
#              Cwd
#              strict
#              vars
# Description: Personal File Manager for Unix/Linux
#
# TO-DO:
# first: test if handlecopyrename() handles double quotes etc. well
#        double quote support by using system(@) for all commands
#        use quotemeta() for quoting?
#        restat after rename?
#        user-customizable columns
#        more &$subptr; instead of eval $substring;
#        config option: sortcurrent (sort current directory?)
#        siZe command
# next:  validate_position should not replace $baseindex when not necessary
#        set ROWS en COLUMNS in environment for child processes; but see if
#            this does not mess up with $scr->getrows etc. which use these
#            variables internally; portability?
#        stat_entry() must *not* rebuild the selected_nr and total_nr lists:
#            this messes up with e.g. cOmmand -> cp \2 /somewhere/else
#            (which is, therefore, still buggy). this is closely related to:
#        sub countdircontents is not used
#        consistent use of gnu ornaments / cyan colored prompt
#        cOmmand -> rm \2 will have to delete the entry from @dircontents;
#            otherwise the mark count is not correct
#
#        major/minor numbers on DU 4.0E are wrong (does readline work there?)
#        key response (flush_input)
# terminal:
#        intelligent restat (changes in current dir?)

##########################################################################
# Main data structures:
#
# @dircontents   : array (current directory data) of references (to file data)
# $dircontents[$index]      : reference (to file data) to hash (file data)
# %{ $dircontents[$index] } : hash (file data)
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
use Config;
use Cwd;
use strict;
#use warnings;
#use diagnostics;
#disable diagnostics; # so we can switch it on in '@'
#$^W = 0;

use vars qw(
    $FIRSTREAD
    $REREAD
    $SHOWSHORT
    $SHOWLONG
    $HIGHLIGHT_OFF
    $HIGHLIGHT_ON
    $FALSE
    $TRUE
    $NARROWTIME
    $WIDETIME
    $SINGLEHEADER
    $MULTIHEADER
    $INCLUDEHEADER
    $MOREHEADER
    $SORTHEADER
    $R_KEY
    $R_HEADER
    $R_STRIDE
    $R_DIRLISTING
    $R_SCREEN
    $R_CLEAR
    $R_DIRCONTENTS
    $R_CHDIR
    $R_QUIT
);

BEGIN {
    $ENV{PERL_RL} = 'Gnu ornaments=1';
}

##########################################################################
# declarations and initialization

*FIRSTREAD     = \0;
*REREAD        = \1;
*SHOWSHORT     = \0;
*SHOWLONG      = \1;
*HIGHLIGHT_OFF = \0;
*HIGHLIGHT_ON  = \1;
*FALSE         = \0;
*TRUE          = \1;
*NARROWTIME    = \0;
*WIDETIME      = \1;
*SINGLEHEADER  = \0;
*MULTIHEADER   = \1;
*INCLUDEHEADER = \2;
*MOREHEADER    = \3;
*SORTHEADER    = \4;
*R_KEY         = \0;
*R_HEADER      = \1;
*R_STRIDE      = \2;
*R_DIRLISTING  = \3;
*R_SCREEN      = \4;
*R_CLEAR       = \5;
*R_DIRCONTENTS = \6;
*R_CHDIR       = \7;
*R_QUIT        = \255;

my $VERSION             = &getversion;
my $CONFIGDIRNAME       = "$ENV{HOME}/.pfm";
my $CONFIGFILENAME      = '.pfmrc';
my $LOSTMSG             = '(file lost)';
my $CWDFILENAME         = 'cwd';
my $MAJORMINORSEPARATOR = ',';
my $MAXHISTSIZE         = 40;
my $ERRORDELAY          = 1;     # seconds
my $SLOWENTRIES         = 300;
my $BASELINE            = 3;
my $USERLINE            = 21;
my $DATELINE            = 22;
my $DATECOL             = 14;
my $RESERVEDSCREENWIDTH = 60;
my $CONFIGFILEMODE      = 0777;

my @SORTMODES = (
    n =>'Name',        N =>' reverse',
   'm'=>' ignorecase', M =>' rev+ignorec',
    e =>'Extension',   E =>' reverse',
    f =>' ignorecase', F =>' rev+ignorec',
    d =>'Date/mtime',  D =>' reverse',
    a =>'date/Atime',  A =>' reverse',
   's'=>'Size',        S =>' reverse',
    t =>'Type',        T =>' reverse',
    i =>'Inode',       I =>' reverse'
);

my %TIMEHINTS = (
    pfm   => '[[CC]YY]MMDDhhmm[.ss]',
    touch => 'MMDDhhmm[[CC]YY][.ss]'
);

my $screenheight    = 20;    # inner height
my $screenwidth     = 80;    # terminal width
my $position_at     = '.';   # start with cursor here

my @command_history = ('du -ks *', 'true');
my @mode_history    = qw(755 644);
my @path_history    = ('/',$ENV{HOME});
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

my (%user, %group, %pfmrc, @signame, %dircolors, $maxfilenamelength,
    $wasresized, $scr, $kbd,
    $uidlineformat, $tdlineformat, $timeformat,
    $sort_mode, $multiple_mode, $uid_mode, $swap_mode, $dot_mode,
    $currentdir, $oldcurrentdir, @dircontents, @showncontents, %currentfile,
    %disk, $swap_state, %total_nr_of, %selected_nr_of,
    $currentline, $baseindex,
    $editor, $pager, $printcmd, $ducmd, $showlockchar, $autoexitmultiple,
    $clobber, $cursorveryvisible, $clsonexit, $autowritehistory, $viewbase,
    $trspace, $swap_persistent,
    $titlecolor, $footercolor, $headercolor, $swapcolor, $multicolor
);

##########################################################################
# read/write resource file and history file

sub write_pfmrc {
    local $_;
    my @resourcefile;
    if (open MKPFMRC,">$CONFIGDIRNAME/$CONFIGFILENAME") {
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

sub read_pfmrc { # $rereadflag - 0=firstread 1=reread (for copyright message)
    $uid_mode = $sort_mode = $editor = $pager = '';
    %dircolors = %pfmrc = ();
    local $_;
    unless (-r "$CONFIGDIRNAME/$CONFIGFILENAME") {
        mkdir $CONFIGDIRNAME, $CONFIGFILEMODE unless -d $CONFIGDIRNAME;
        &write_pfmrc;
    }
    if (open PFMRC,"<$CONFIGDIRNAME/$CONFIGFILENAME") {
        while (<PFMRC>) {
            s/#.*//;
            if (s/\\\n?$//) { $_ .= <PFMRC>; redo; }
            if ( /^\s*       # whitespace at beginning
                  ([^:\s]+)  # keyword
                  \s*:\s*    # separator (:), may have whitespace around it
                  (.*)$/x )  # value - allow spaces
            { $pfmrc{$1} = $2; }
        }
        close PFMRC;
    }
    if (defined($pfmrc{usecolor}) && ($pfmrc{usecolor} eq 'force')) {
        $scr->colorizable($TRUE);
    } elsif (defined($pfmrc{usecolor}) && ! &yesno($pfmrc{usecolor})) {
        $scr->colorizable($FALSE);
    }
    &copyright($pfmrc{copyrightdelay}) unless ($_[0]);
    $cursorveryvisible = &yesno($pfmrc{cursorveryvisible});
    system ('tput', $cursorveryvisible ? 'cvvis' : 'cnorm');
    system ('stty', 'erase', $pfmrc{erase}) if defined($pfmrc{erase});
    $kbd->set_keymap($pfmrc{keymap})        if $pfmrc{keymap};
    # some configuration options are NOT fetched into common scalars
    # (e.g. confirmquit) - however, they remain accessable in %pfmrc
    $clsonexit         = &yesno($pfmrc{clsonexit});
    $clobber           = &yesno($pfmrc{clobber});
    $dot_mode          = &yesno($pfmrc{dotmode});
    $autowritehistory  = &yesno($pfmrc{autowritehistory});
    $autoexitmultiple  = &yesno($pfmrc{autoexitmultiple});
    $swap_persistent   = &yesno($pfmrc{persistentswap});
    $trspace           = &yesno($pfmrc{translatespace}) ? ' ' : '';
    ($printcmd)        = ($pfmrc{printcmd}) ||
                             ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER}" : 'lpr');
    $ducmd             = $pfmrc{ducmd} ||
                             q(du -sk | awk '{printf "%d", 1024 * $1}');
    $timeformat        = $pfmrc{timeformat} || 'pfm';
    $sort_mode         = $pfmrc{sortmode}   || 'n';
    $uid_mode          = 2*($pfmrc{uidmode} eq 'atime')
                         + ($pfmrc{uidmode} eq 'uid');
    $headercolor       = $pfmrc{headercolor} || '37;44';
    $multicolor        = $pfmrc{multicolor}  || '36;47';
    $titlecolor        = $pfmrc{titlecolor}  || '36;47;07;01';
    $swapcolor         = $pfmrc{swapcolor}   || '36;40;07';
    $footercolor       = $pfmrc{footercolor} || '34;47;07';
    $viewbase          = $pfmrc{viewbase} eq 'hex' ? "%#04lx" : "%03lo";
    $showlockchar      = ( $pfmrc{showlock} eq 'sun' && $^O =~ /sun|solaris/i
                             or &yesno($pfmrc{showlock}) ) ? 'l' : 'S';
    $editor            = $ENV{EDITOR} || $pfmrc{editor} || 'vi';
    $pager             = $ENV{PAGER}  || $pfmrc{pager}  ||
                             ($^O =~ /linux/i ? 'less' : 'more');
    $pfmrc{dircolors} ||= $ENV{LS_COLORS} || $ENV{LS_COLOURS};
    if ($pfmrc{dircolors}) {
        while ($pfmrc{dircolors} =~ /([^:=*]+)=([^:=]+)/g ) {
            $dircolors{$1} = $2;
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
            /([\d\.]+)/ and $ver = "$1";
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
    my ($monname,$val);
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);
    $monname =(qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$mon];
    foreach $val ($mday, $hour, $min, $sec) {
        if ($val < 10) {
            $val = "0$val";
        }
    }
    if ($_[1] == $WIDETIME) {
        $min = "$min:$sec";
        $year += 1900;
    } else {
        $year %= 100;
    }
    if ($year<10) { $year = "0$year" }
    return "$year $monname $mday $hour:$min";
}

sub mode2str {
    my $strmode;
    my $nummode  = shift; # || 0;
    my $octmode  = sprintf("%lo", $nummode);
    my @strmodes = (qw/--- --x -w- -wx r-- r-x rw- rwx/);
    $octmode     =~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
    $strmode     = substr('-pc?d?b?-?l?s?=D=?=?d', oct($1), 1)
                 . $strmodes[$3] . $strmodes[$4] . $strmodes[$5];
                 # first  - is continuation inode for ext2,
                 # second - is regular file
                 # first  d for Linux, OSF1, Solaris
                 # second d for AIX
    if ($2 & 4) {       substr( $strmode,3,1) =~ tr/-x/Ss/ }
    if ($2 & 2) { eval "substr(\$strmode,6,1) =~ tr/-x/${showlockchar}s/" }
    if ($2 & 1) {       substr( $strmode,9,1) =~ tr/-x/Tt/ }
    return $strmode;
}

sub fit2limit {
    my $neatletter = '';
    my $neatsize = $_[0]; # might be uninitialized or major/minor
    my $LIMIT = 9_999_999;
    while ( $neatsize > $LIMIT ) {
        $neatsize = int($neatsize/1024);
        $neatletter =~ tr/KMGT/MGTP/ || do { $neatletter = 'K' };
#        $LIMIT = 999_999;
    }
    return ($neatsize, $neatletter);
}

sub expand_12_escapes {
    my %thisfile = %{$_[1]};
    my $namenoext =
        $thisfile{name} =~ /^(.*)\.([^\.]+)$/ ? $1 : $thisfile{name};
    # there must be an odd nr. of backslashes before the digit
    # because \\ must be interpreted as an escaped backslash
#    $_[0] =~ s/((?:[^\\]|^)(?:\\\\)*)\\1/$1$namenoext/g;
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

# alternatively
#sub max (@) {
#    return +(sort { $b <=> $a } @_)[0];
#}

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
    my $target = $_[0];
    my $result;
    if ($result = &findchangedir($target) and $target ne $currentdir) {
        $oldcurrentdir = $currentdir;
    }
    $currentdir = getcwd() || $ENV{HOME};
    return $result;
}

sub inhibit ($$) {
    return !$_[1] && $_[0];
}

sub triggle ($) {
    $_[0]-- or $_[0] = 2;
}

sub toggle ($) {
    $_[0] = !$_[0];
}

sub basename {
    $_[0] =~ /\/([^\/]*)$/; # ok, it is LTS but this looks better in vim
    return $1;
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

sub dirlookup {
    my ($name, @array) = @_;
    my $found = $#array;
    while ($found >= 0 and $array[$found]{name} ne $name) {
        $found--;
    }
    return $found;
}

sub copyback { # copy a changed entry from @showncontents back to @dircontents
    my $somefilename = $_[0];
    $dircontents[&dirlookup($somefilename, @dircontents)] =
        $showncontents[$currentline+$baseindex];
}

##########################################################################
# apply color

sub digestcolor {
    return unless defined $_[0];
    foreach (split /;/,$_[0]) { $scr->color($_) }
}

sub decidecolor {
    my %file = @_;
    $file{type} eq 'd'       and &digestcolor($dircolors{di}), return;
    $file{type} eq 'l'       and &digestcolor($dircolors{ln}), return;
    $file{type} eq 'b'       and &digestcolor($dircolors{bd}), return;
    $file{type} eq 'c'       and &digestcolor($dircolors{cd}), return;
    $file{type} eq 'p'       and &digestcolor($dircolors{pi}), return;
    $file{type} eq 's'       and &digestcolor($dircolors{so}), return;
    $file{type} eq 'D'       and &digestcolor($dircolors{'do'}), return;
    $file{mode} =~ /[xst]/   and &digestcolor($dircolors{ex}), return;
    $file{name} =~/(\.\w+)$/ and &digestcolor($dircolors{$1}), return;
}

sub applycolor {
    if ($scr->colorizable()) {
        my ($line, $length, %file) = (shift, shift, @_);
        $length = $length ? 255 : $screenwidth - $RESERVEDSCREENWIDTH;
        &decidecolor(%file);
        $scr->at($line,2)->puts(substr($file{name},0,$length))->normal();
    }
}

##########################################################################
# small printing routines

sub makeformatlines {
    $uidlineformat ='@ @' . '<' x ($screenwidth - $RESERVEDSCREENWIDTH - 1)
                   .'@@>>>>>>@ @<<<<<<< @<<<<<<<@###  @<<<<<<<<<';
    $tdlineformat  ='@ @' . '<' x ($screenwidth - $RESERVEDSCREENWIDTH - 1)
                   .'@@>>>>>>@ @<<<<<<<<<<<<<<@###### @<<<<<<<<<';
}

sub pathline {
    # pfff.. this has become very complicated since we wanted to handle
    # all those exceptions
    my ($path, $dev) = @_;
    my $overflow     = ' ';
    my $ELISION      = '..';
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
            unless ($path =~ /^(\/[^\/]+?\/)(.+)/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /some_insanely_long_directoryname
                $disppath = substr($path, 0, $maxpathlen);
                $overflow = '+';
                last FIT;
            }
            ($disppath, $path) = ($1, $2);
            # the one being subtracted is for the '/' char in the next match
            $restpathlen = $maxpathlen -length($disppath) -length($ELISION) -1;
            unless ($path =~ /(\/.{1,$restpathlen})$/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /usr/someinsanelylongdirectoryname
                $disppath = substr($disppath.$path, 0, $maxpathlen);
                $overflow = '+';
                last FIT;
            }
            # pathname component candidate for replacement found; name will fit
            $disppath .= $ELISION . $1;
        }
    }
    return $disppath . ' 'x max($maxpathlen -length($disppath), 0)
         . $overflow . "[$dev]";
}

sub uidline {
    $^A = "";
    formline($uidlineformat,@_);
    return $^A;
}

sub tdline {
    $^A = "";
    formline($tdlineformat, @_[0..4], &time2str($_[5],$NARROWTIME), @_[6,7]);
    return $^A;
}

sub fileline {
    my %specs = @_;
    my ($neatsize, $ofchar) = &fit2limit($specs{size});
    unless ($uid_mode) {
        return  &tdline( @specs{qw/selected display too_long/},
                         $neatsize, $ofchar,
                         @specs{qw/mtime inode mode/}        );
    } elsif ($uid_mode == 1) {
        return &uidline( @specs{qw/selected display too_long/},
                         $neatsize, $ofchar,
                         @specs{qw/uid gid nlink mode/}      );
    } else {
        return  &tdline( @specs{qw/selected display too_long/},
                         $neatsize, $ofchar,
                         @specs{qw/atime inode mode/}        );
    }
}

sub highlightline { # true/false
    $scr->at($currentline + $BASELINE, 0);
    $scr->bold() if ($_[0] == $HIGHLIGHT_ON);
    $scr->puts(&fileline(%currentfile));
    &applycolor($currentline + $BASELINE, $SHOWSHORT, %currentfile);
    $scr->normal()->at($currentline + $BASELINE, 0);
}

sub markcurrentline { # letter
    $scr->at($currentline + $BASELINE, 0)->puts($_[0]);
}

sub pressanykey {
    $scr->cyan();
    print "\n*** Hit any key to continue ***";
    $scr->normal()->raw()->getch();
}

sub display_error {
#    $scr->at(0,0)->clreol();
    $scr->cyan()->bold()->puts($_[0])->normal();
    return $scr->key_pressed($ERRORDELAY); # return value not actually used
}

sub ok_to_remove_marks {
    my $sure;
    if (&mark_info) {
        $sure = $scr->at(0,0)->clreol()->bold()->cyan()
                    ->puts("OK to remove marks [Y/N]? ")->normal()->getch();
        &init_header($multiple_mode);
        return ($sure =~ /y/i);
    }
    1;
}

sub promptforwildfilename {
    my $prompt = 'Wild filename (regular expression): ';
    my $wildfilename;
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($prompt)->normal();
    $wildfilename = &readintohist(\@regex_history, $prompt); #### ornaments
    $scr->raw();      # init_header is done in handleinclude
    eval "/$wildfilename/";
    if ($@) {
        &display_error($@);
        $scr->key_pressed(2);  # add two seconds
        $wildfilename = '^$';  # clear illegal regexp
    }
    return $wildfilename;
}

sub clearcolumn {
    local $_;
    my $spaces = ' ' x $DATECOL;
    foreach ($BASELINE .. $BASELINE+$screenheight) {
        $scr->at($_, $screenwidth-$DATECOL)->puts($spaces);
    }
}

sub path_info {
    $scr->at(1,0)->puts(&pathline($currentdir,$disk{'device'}));
}

##########################################################################
# headers, footers

sub print_with_shortcuts {
    my ($printme, $pattern) = @_;
    my $pos;
    &digestcolor($headercolor);
    $scr->puts($printme)->bold();
    while ($printme =~ /$pattern/g) {
        $pos = pos($printme) -1;
        $scr->at(0, $pos)->puts(substr($printme, $pos, 1));
    }
    $scr->normal();
}

sub init_frame { # multiple_mode, swap_mode, uid_mode
   &init_header($_[0]);
   &init_title(@_[1,2]);
   &init_footer;
}

sub init_header { # "multiple"mode
    my $mode = $_[0];
    my @header = split(/\n/,<<_eoFirst_);
Attr Time Copy Del Edit Find Print Ren Show Uid View Your cOmmand Quit siZe More
Multiple Include eXclude Attribute Time Copy Delete Print Rename Your cOmmands  
Include? Every, Oldmarks, User or Files only:                                   
Config PFM Edit new file Make new dir Show new dir sHell Kill Write history ESC 
Sort by: Name, Extension, Size, Date, Type, Inode (ignorecase, reverse):        
_eoFirst_
    $scr->at(0,0);
    &print_with_shortcuts($header[$mode].' 'x($screenwidth - 80),
                          "[A-Z](?!FM|M E| Ed)");
    if ($mode == 1) {
        &digestcolor($multicolor);
        $scr->reverse()->bold()->at(0,0)->puts("Multiple")->normal();
    }
}

sub init_title { # swap_mode, uid_mode
    my ($smode, $umode) = @_;
    my $linecolor;
    my @title = split(/\n/,<<_eoHead_);
size  date      mtime  inode attrib          disk info
size  userid   groupid lnks  attrib          disk info
size  date      atime  inode attrib          disk info
size  date      mtime  inode attrib     your commands 
size  userid   groupid lnks  attrib     your commands 
size  date      atime  inode attrib     your commands 
size  date      mtime  inode attrib     sort mode     
size  userid   groupid lnks  attrib     sort mode     
size  date      atime  inode attrib     sort mode     
size  date      mtime  inode attrib       nr signal   
size  userid   groupid lnks  attrib       nr signal   
size  date      atime  inode attrib       nr signal   
_eoHead_
    &digestcolor($linecolor = $smode ? $swapcolor : $titlecolor);
    $scr->reverse() if ($linecolor =~ /\b0?7\b/);
    $scr->bold()    if ($linecolor =~ /\b0?1\b/);
    $scr->at(2,0)
        ->puts('  filename.ext'.' 'x($screenwidth-$DATECOL-54).$title[$umode])
        ->normal();
}

sub init_footer {
    my $footer;
    chop($footer = <<_eoFunction_);
F1-Help F2-Back F3-Fit F4-Color F5-Read F6-Sort F7-Swap F8-Incl F9-Uid F10-Multi
_eoFunction_
    &digestcolor($footercolor);
    $scr->reverse() if ($footercolor =~ /\b0?7\b/);
    $scr->bold()->at($BASELINE+$screenheight+1,0)
        ->puts($footer.' 'x($screenwidth-80))->normal();
}

sub copyright {
    $scr->cyan()->puts("PFM $VERSION for Unix computers and compatibles.")
        ->at(1,0)->puts("Copyright (c) 1999-2002 Rene Uittenbogaard")
        ->at(2,0)->puts("This software comes with no warranty: see the file "
                       ."COPYING for details.")->normal();
    return $scr->key_pressed($_[0]);
}

sub globalinit {
    $SIG{WINCH} = \&resizecatcher;
    $scr = Term::ScreenColor->new();
    $scr->clrscr();
    $kbd = Term::ReadLine->new('Pfm', \*STDIN, \*STDOUT);
    &read_pfmrc($FIRSTREAD);
    &read_history;
    %user    = &init_uids;
    %group   = &init_gids;
    @signame = &init_signames;
    %selected_nr_of = %total_nr_of = ();
    $swap_state = $swap_mode = $multiple_mode = 0;
    if ($scr->getrows()) { $screenheight = $scr->getrows()-$BASELINE-2 }
    if ($scr->getcols()) { $screenwidth  = $scr->getcols() }
    $maxfilenamelength = $screenwidth - $RESERVEDSCREENWIDTH;
    $baseindex = 0;
    &makeformatlines;
    # uid_mode has been set from .pfmrc
    &init_frame($multiple_mode, $swap_mode, $uid_mode);
    # now find starting directory
    $oldcurrentdir = $currentdir = getcwd();
    $ARGV[0] and &mychdir($ARGV[0]) || do {
        $scr->at(0,0)->clreol();
        &display_error("$ARGV[0]: $! - using .");
        $scr->key_pressed(1); # add another second error delay
        &init_header($SINGLEHEADER);
    };
}

sub goodbye {
    my $bye = 'Goodbye from your Personal File Manager!';
    if ($clsonexit) {
        $scr->cooked()->clrscr();
    } else {
        $scr->at(0,0)->puts(' 'x(($screenwidth-length $bye)/2).$bye)->clreol()
            ->cooked()->normal()->at(1,0);
    }
    &write_cwd;
    &write_history if $autowritehistory;
    unless ($clsonexit) {
        $scr->at($screenheight+$BASELINE+1,0)->clreol()->cooked();
    }
    system qw(tput cnorm) if $cursorveryvisible;
}

sub credits {
    $scr->clrscr()->cooked();
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
    $scr->raw()->getch();
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
    # I played with vt100 boxes once,      lqqk
    # but I hated it.                      x  x
    # In case someone wants to try:        mqqj
#    $scr->at($startline-1,$screenwidth-$DATECOL)
#        ->puts("\cNlq\cODisk space\cNqk\cO");
    $scr->at($startline-1,$screenwidth-$DATECOL+4)->puts('Disk space');
    foreach (0..2) {
        while ( $values[$_] > 99_999 ) {
                $values[$_] /= 1024;
                $desc[$_] =~ tr/KMGT/MGTP/;
        }
        $scr->at($startline+$_,$screenwidth-$DATECOL+1)
            ->puts(&infoline(int($values[$_]),$desc[$_]));
    }
}

sub dir_info {
    local $_;
    my @desc   = qw/files dirs symln spec/;
    my @values = @total_nr_of{'-','d','l'};
    $values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
               + $total_nr_of{'p'} + $total_nr_of{'s'}
               + $total_nr_of{'D'};
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
               + $selected_nr_of{'D'};
    my $startline = 15;
    my $total = 0;
    $values[0] = join ('', &fit2limit($values[0]));
    $scr->at($startline-1, $screenwidth-$DATECOL+2)->puts('Marked files');
    foreach (0..4) {
        $scr->at($startline+$_, $screenwidth-$DATECOL+1)
            ->puts(&infoline($values[$_],$desc[$_]));
        $total += $values[$_] if $_;
    }
    return $total;
}

sub date_info {
    my ($line, $col) = @_;
    my ($datetime, $date, $time);
    $datetime = &time2str(time, $WIDETIME);
    ($date, $time) = ($datetime =~ /(.*)\s+(.*)/);
    $scr->at($line++, $col+3)->puts($date) if ($scr->getrows() > 24);
    $scr->at($line++, $col+6)->puts($time);
}

##########################################################################
# sorting subs

sub as_requested {
    my ($exta, $extb);
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
    return $R_QUIT if $pfmrc{confirmquit} =~ /^(never|no|false|0)$/i;
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
    triggle($uid_mode);
    &init_title($swap_mode,$uid_mode);
    return $R_DIRLISTING;
}

sub handlerefresh {
    return &ok_to_remove_marks ? $R_DIRCONTENTS : $R_KEY;
}

sub handlecolor {
    $scr->colorizable(!$scr->colorizable());
    return $R_CLEAR;
}

sub handleadvance {
    &handleselect;
    goto &handlemove; # this autopasses the " " key in $_[0] to &handlemove
}

sub handlesize {
    my $recursivesize;
    &markcurrentline('Z'); # disregard multiple_mode
    # du(1) is a bitch... that's why we have ppl specify their ducmd in .pfmrc
    # AIX,BSD,Tru64: gives blocks (), kbytes (-k)
    # Solaris      : gives kbytes ()
    # HP           : gives blocks (), something unwanted (-b)
    # Linux        : gives blocks (), kbytes (-k), bytes (-b)
    ($recursivesize = `$ducmd \Q$currentfile{name}`) =~ s/\D*(\d+).*/$1/;
#    unless ($?) { # think about what to do when $? != 0 ?
        $scr->at($currentline + $BASELINE, 0);
        $scr->puts(&fileline(%currentfile, size => $recursivesize));
        &markcurrentline('Z');
        &applycolor($currentline + $BASELINE, $SHOWSHORT, %currentfile);
        $scr->getch();
#    }
    return $R_KEY;
}

sub handledot {
    &toggle($dot_mode);
    @showncontents = &filterdir(@dircontents);
#    if ($currentline + $baseindex > @showncontents) {
#        $currentline = @showncontents - $baseindex +1;
#    }
    $position_at = $currentfile{name};
#    &validate_position;
    return $R_SCREEN;
}

sub handleshowenter {
    my $followmode = &mode2str((stat $currentfile{name})[2]);
    if ($followmode =~ /^d/) {
        goto &handleentry;
    } else {
        if ($_[0] =~ /\r/ and $followmode =~ /x/) {
            goto &handleenter;
        } else {
            goto &handleshow;
        }
    }
    die "exception in handleshowenter()"; # this point should not be reached
}

sub handlecdold {
    if (&ok_to_remove_marks) {
        &mychdir($oldcurrentdir);
        return $R_CHDIR;
    } else {
        return $R_KEY;
    }
}

sub handlefind {
    my $findme;
    my $prompt = 'File to find: ';
    $scr->at(0,0)->clreol()->cooked();
#    $scr->cyan()->bold()->puts($prompt)->normal()->at(0,14);
    ($findme = &readintohist(\@path_history, $prompt)) =~ s/\/$//; # ornaments
    if ($findme =~ /\//) { $findme = basename($findme) };
    $scr->raw();
    return $R_HEADER unless $findme;
    FINDENTRY:
    foreach (sort by_name @showncontents) {
        if ( $_->{name} =~ /^$findme/ ) {
            $position_at = $_->{name};
            last FINDENTRY;
        }
    }
    return $R_SCREEN;
}

sub handlefit {
    local $_;
    $scr->resize();
    my $newheight = $scr->getrows();
    my $newwidth  = $scr->getcols();
    if ($newheight || $newwidth) {
#        $ENV{ROWS}    = $newheight;
#        $ENV{COLUMNS} = $newwidth;
        $screenheight = $newheight - $BASELINE - 2;
        $screenwidth  = $newwidth;
        $maxfilenamelength = $screenwidth - $RESERVEDSCREENWIDTH;
        &makeformatlines;
        foreach (@dircontents) {
            $_->{too_long} = length($_->{display}) > $maxfilenamelength ? '+'
                                                                        : ' ';
        }
        return $R_CLEAR;
    }
}

sub handleperlcommand {
    my $perlcmd;
    my $prompt = 'Enter Perl command:';
    $scr->at(0,0)->clreol()->cyan()->bold()->puts($prompt)->normal()
        ->at(1,0)->clreol()->cooked();
    $perlcmd = &readintohist(\@perlcmd_history);
    $scr->raw();
    eval $perlcmd;
    &display_error($@) if $@;
    return $R_SCREEN;
}

sub handlemoreshow {
    my $newname;
    my $do_a_refresh = $R_SCREEN;
    my $stateprompt  = 'Directory Pathname: ';
    return $R_HEADER unless &ok_to_remove_marks;
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($stateprompt)->normal()->at(0,20);
    $newname = &readintohist(\@path_history, $stateprompt); # ornaments
    $scr->raw();
    $position_at = '.';
    &expand_escapes($newname, \%currentfile);
    if ( !&mychdir($newname) ) {
#        $currentdir = getcwd();
        &display_error("$newname: $!");
    } else {
#        ($oldcurrentdir, $currentdir) = ($currentdir, $newname);
        $do_a_refresh = $R_CHDIR;
    }
    return $do_a_refresh;
}

sub handlemoremake {
    my $newname;
    my $do_a_refresh = $R_SCREEN;
    my $stateprompt  = 'New Directory Pathname: ';
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($stateprompt)->normal()->at(0,24);
    $newname = &readintohist(\@path_history, $stateprompt); # ornaments
    $scr->raw();
    if ( !mkdir $newname,0777 ) {
        &display_error("$newname: $!");
    } else {
# could this be enough?
#        return $R_HEADER unless &ok_to_remove_marks;
        return $R_SCREEN unless &ok_to_remove_marks;
        $do_a_refresh = $R_CHDIR;
        if ( !&mychdir($newname) ) {
            &display_error("$newname: $!"); # e.g. by restrictive umask
        } else {
#            ($oldcurrentdir, $currentdir) = ($currentdir, getcwd());
            $position_at = '.';
        }
    }
    return $do_a_refresh;
}

sub handlemoreconfig {
    if (system $editor, "$CONFIGDIRNAME/$CONFIGFILENAME") {
        &display_error($!);
    } else {
        &read_pfmrc($REREAD);
    }
    $scr->clrscr();
    return $R_CLEAR;
}


sub handlemoreedit {
    my $newname;
    my $stateprompt  = 'New name: ';
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($stateprompt)->normal()->at(0,10);
    $newname = &readintohist(\@path_history, $stateprompt); #ornaments
    system ($editor, $newname) and &display_error($!);
    $scr->raw();
    return $R_CLEAR;
}

sub handlemorekill {
    my $printline   = $BASELINE;
    my $stateprompt = 'Signal to send to child processes: ';
    my $signal      = 'TERM';
    &init_title($swap_mode, $uid_mode+9);
    &clearcolumn;
    foreach (1 .. min($#signame, $screenheight)+1) {
        $^A = "";
        formline('@# @<<<<<<<<', $_, $signame[$_]);
        $scr->at($printline++, $screenwidth-$DATECOL+2)->puts($^A);
    }
    $scr->at(0,0)->clreol()->cooked();
    $signal = $kbd->readline($stateprompt, $signal); # special case
    $scr->raw();
    &clearcolumn;
    return $R_SCREEN unless $signal;
    if ($signal !~ /\D/) {
        $signal = $signame[$signal];
    }
    local $SIG{$signal} = 'IGNORE';
    kill -$signal, $$;
    return $R_SCREEN;
}

sub handlemoreshell {
    $scr->clrscr->cooked;
#    @ENV{qw(ROWS COLUMNS)} = ($screenheight + $BASELINE + 2, $screenwidth);
    system ($ENV{SHELL} ? $ENV{SHELL} : 'ksh'); # most portable
#    $scr->raw; # done in &pressanykey
    &pressanykey;
    return $R_CLEAR;
}

sub handlemore {
    local $_;
    my $do_a_refresh = $R_SCREEN;
    my ($newname, $stateprompt);
    &init_header($MOREHEADER);
    my $key = $scr->at(0,79)->getch();
    MOREKEY: for ($key) {
        /^s$/i and $do_a_refresh = &handlemoreshow,   last MOREKEY;
        /^m$/i and $do_a_refresh = &handlemoremake,   last MOREKEY;
        /^c$/i and $do_a_refresh = &handlemoreconfig, last MOREKEY;
        /^e$/i and $do_a_refresh = &handlemoreedit,   last MOREKEY;
        /^h$/i and $do_a_refresh = &handlemoreshell,  last MOREKEY;
        /^w$/i and &write_history,                    last MOREKEY;
        /^k$/i and &handlemorekill,                   last MOREKEY;
#        /^p$/i and &handlemoreprocgroup,              last MOREKEY;
    }
    return $do_a_refresh;
}

sub handleinclude { # include/exclude flag (from keypress)
    local $_;
    my $do_a_refresh = $R_HEADER;
    my $exin = $_[0];
    my $criterion;
    our ($wildfilename, $entry);
    # $wildfilename could have been declared using my(), but that will prevent
    # changes in its value to be noticed by the anonymous sub
    &init_header($INCLUDEHEADER);
    # modify header to say "exclude" when 'x' was pressed
    if ($exin =~ /x/i) { $scr->at(0,0)->on_blue()->puts('Ex')->normal(); }
    $exin =~ tr/ix/* /;
    my $key = $scr->at(0,46)->getch();
    if ($key =~ /^o$/i) {   # include oldmarks
        foreach $entry (@showncontents) {
            if ($entry->{selected} eq '.' && $exin eq ' ') {
                $entry->{selected} = $exin;
            } elsif ($entry->{selected} eq '.' && $exin eq '*') {
                &include($entry);
            }
            $do_a_refresh = $R_SCREEN;
        }
    };
    if ($key =~ /^[efu]$/i) {
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
                $do_a_refresh = $R_SCREEN;
            }
        }
    } # if $key =~ /[efu]/
    return $do_a_refresh;
}

sub handleview {
    &markcurrentline('V'); # disregard multiple_mode
    my $viewline = $currentfile{target};
    my $removed = ($viewline =~ s/^ -> //);
    # we are allowed to alter %currentfile because we will exit with
    # at least $R_STRIDE; &browse will re-assign %currentfile
    for ($currentfile{name}, $viewline) {
        s/\\/\\\\/;
        # don't ask how this works
        s{([${trspace}\177[:cntrl:]]|[^[:ascii:]])}
         {'\\'.sprintf($viewbase,unpack('C',$1))}eg;
    }
    $scr->at($currentline+$BASELINE,2)->bold()
        # erase char after name, under cursor
        ->puts($currentfile{name} . ($removed?' -> ':'') . $viewline . " \cH");
    &applycolor($currentline+$BASELINE, $SHOWLONG, %currentfile);
    $scr->getch();
    if (length($currentfile{display}) > $screenwidth-$DATECOL-2) {
        return $R_CLEAR;
    } else {
        return $R_STRIDE;
    }
}

sub handlesort {
    my ($i, $key);
    my $printline = $BASELINE;
    my %sortmodes = @SORTMODES;
    &init_header($SORTHEADER);
    &init_title($swap_mode, $uid_mode+6);
    &clearcolumn;
    # we can't use foreach (keys %SORTMODES) because we would lose ordering
    foreach (grep { ($i += 1) %= 2 } @SORTMODES) { # keep keys, skip values
        $^A = "";
        formline('@ @<<<<<<<<<<<', $_, $sortmodes{$_});
        $scr->at($printline++, $screenwidth-$DATECOL)->puts($^A);
    }
    $key = $scr->at(0,73)->getch();
    &clearcolumn;
    &init_header($multiple_mode);
    if ($sortmodes{$key}) {
        $sort_mode   = $key;
        $position_at = $currentfile{name};
        @dircontents = sort as_requested @dircontents;
    }
    return $R_SCREEN; # the column with sort modes should be restored anyway
}

sub handlechown {
    my ($newuid, $loopfile, $do_this, $index);
    my $prompt = 'New user[:group] : ';
    my $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('U') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cooked();
    chomp($newuid = &readintohist(\@mode_history, $prompt)); # ornaments
#    chop ($newuid = <STDIN>);
    $scr->raw();
    return $R_HEADER if ($newuid eq '');
    $do_this = 'system qq/chown '.$newuid.' $loopfile->{name}/ '
             . 'and &display_error($!), $do_a_refresh = $R_SCREEN';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                eval($do_this);
                $dircontents[$index] =
                    &stat_entry($loopfile->{name}, $loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        eval($do_this);
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handlechmod {
    my ($newmode, $loopfile, $do_this, $index);
    my $prompt = 'Permissions ( [ugoa][-=+][rwxslt] or octal ): ';
    my $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cooked();
    chomp($newmode = &readintohist(\@mode_history, $prompt)); # ornaments
    $scr->raw();
    return $R_HEADER if ($newmode eq '');
    if ($newmode =~ /^\s*(\d+)\s*$/) {
        $do_this =           'chmod '.oct($1).  ',$loopfile->{name} '
                  .'or  &display_error($!), $do_a_refresh = $R_SCREEN';
    } else {
        $newmode =~ s/\+l/g+s,g-x/;
        $newmode =~ s/\-l/g-s,g+x/;
        $do_this = 'system qq/chmod '.$newmode.' "$loopfile->{name}"/'
                  .'and &display_error($!), $do_a_refresh = $R_SCREEN';
    }
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                eval($do_this);
                $dircontents[$index] =
                    &stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        eval($do_this);
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
        &init_title($swap_mode,$uid_mode+3);
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
        return $R_SCREEN unless ($command = $pfmrc{uc($key)}); # assignment!
        $scr->cooked();
    } else { # cOmmand
        $printstr = <<'_eoPrompt_';
Enter Unix command (\1=name, \2=name.ext, \3=path, \4=mountpoint, \5=swap path):
_eoPrompt_
        $scr->at(0,0)->clreol()->bold()->cyan()->puts($printstr)->normal()
            ->at(1,0)->clreol()->cooked();
        $command = &readintohist(\@command_history);
    }
#    $command =~ s/^\s*\n?$/$ENV{'SHELL'}/;
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
                    system ($do_this) and &display_error($!);
                    $dircontents[$index] =
                        &stat_entry($loopfile->{name},$loopfile->{selected});
#                    if ($dircontents[$index]{mode} =~ /^\?/) {
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
            system ($command) and &display_error($!);
            $showncontents[$currentline+$baseindex] =
                &stat_entry($currentfile{name}, $currentfile{selected});
            if ($showncontents[$currentline+$baseindex]{nlink} == 0) {
                $showncontents[$currentline+$baseindex]{display} .= " $LOSTMSG";
            }
            &copyback($currentfile{name});
        }
        &pressanykey;
    }
    $scr->raw();
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
    $scr->at(1,0);
    # don't allow people to delete '.': normally, this would be allowed if it
    # is empty, but if that leaves the parent directory empty, then it can also
    # be removed, which causes a fatal error.
    $do_this = q"if ($loopfile->{type} eq 'd') {
                     if ($loopfile->{name} eq '.') {
                         $success = 0;
                         $msg = 'Deleting current directory not allowed';
                     } else {
                         $success = rmdir $loopfile->{name};
                     }
                 } else {
                     $success = unlink $loopfile->{name};
                 }
                 if ($success) {
                     $total_nr_of{$loopfile->{type}}--;
                     &exclude($loopfile) if $loopfile->{selected} eq '*';
                 } else { # not success
                     &display_error($msg || $!);
                 }
                 ";
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
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                eval($do_this);
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
        eval($do_this);
        if ($success) {
            splice @dircontents, &dirlookup($loopfile->{name}, @dircontents), 1;
            splice @showncontents, $currentline+$baseindex, 1;
        }
    }
    # this prevents the cursor from running out of @showncontents;
    # otherwise, the validate_position() call is pointless
    while (!$position_at and $currentline+$baseindex > $#showncontents) {
        $currentline--;
    }
    &validate_position;
    return $R_SCREEN;
}

sub handleprint {
    my ($loopfile, $do_this, $index);
    &markcurrentline('P') unless $multiple_mode;
#    $scr->at(0,0)->clreol();
    $scr->at(0,0)->clreol()
        ->bold()->cyan()->puts('Enter print command: ')->normal()
        ->at(1,0)->clreol()->cooked();
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
    $scr->raw();
    return $R_SCREEN if $do_this eq '';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile, '.');
                system qq/$do_this "$loopfile->{name}"/ and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system qq/$do_this "$currentfile{name}"/ and &display_error($!);
    }
    return $R_SCREEN;
}

sub handleshow {
    my ($loopfile,$index);
    $scr->clrscr()->at(0,0)->cooked();
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                &exclude($loopfile,'.');
                system (qq/$pager "$loopfile->{name}"/) and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system qq/$pager "$currentfile{name}"/ and &display_error($!);
    }
    $scr->raw();
    return $R_CLEAR;
}

sub handlehelp {
    $scr->clrscr();
    system qw(man pfm); # how unsubtle :-)
    &credits;
    return $R_CLEAR;
}

sub handletime {
    my ($newtime, $loopfile, $do_this, $index, $do_a_refresh);
    my $prompt = "Put date/time $TIMEHINTS{$timeformat}: ";
    $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('T') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($prompt)->normal();
    $newtime = &readintohist(\@time_history, $prompt); # ornaments
    $scr->raw();
    return $R_HEADER if ($newtime eq '');
    # convert date/time to touch format if necessary
    if ($timeformat eq 'pfm') {
        $newtime =~ s/^(\d{0,4})(\d{8})(\..*)?/$2$1$3/;
    }
    if ($newtime eq '.') {
        $newtime = '';
    } else {
        $newtime = "-t $newtime";
    }
    $do_this = "system qq/touch $newtime \$loopfile->{name}/ "
              .'and &display_error($!), $do_a_refresh = $R_SCREEN';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                eval($do_this);
                $dircontents[$index] =
                    &stat_entry($loopfile->{name},$loopfile->{selected});
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        eval($do_this);
        $showncontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
        &copyback($currentfile{name});
    }
    return $do_a_refresh;
}

sub handleedit {
    my ($loopfile, $index);
    $scr->clrscr()->at(0,0)->cooked();
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                &exclude($loopfile, '.');
                system qq/$editor "$loopfile->{name}"/ and &display_error($!);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        system qq/$editor "$currentfile{name}"/ and &display_error($!);
    }
    $scr->clrscr()->raw();
    return $R_SCREEN;
}

sub handlecopyrename {
    my $state = "\u$_[0]";
    my $statecmd = ($state eq 'C' ? 'cp' : 'mv');
    my $stateprompt = $state eq 'C' ? 'Destination: ' : 'New name: ';
    my ($loopfile, $index, $newname, $newnameexpanded, $command);
    my $do_a_refresh = $R_HEADER;
    &markcurrentline($state) unless $multiple_mode;
    $scr->at(0,0)->clreol()->cooked();
#    $scr->bold()->cyan()->puts($stateprompt)->normal();
    push (@path_history, $currentfile{name}) unless $multiple_mode;
    $scr->at(0,0);
    $newname = &readintohist(\@path_history, $stateprompt);     # ornaments
    if ($#path_history > 0 and $path_history[-1] eq $path_history[-2]) {
        pop @path_history;
    }
    $scr->raw();
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
    $command = 'system ($statecmd,' . ($clobber ? '' : "'-i',") .
               '$loopfile->{name}, $newnameexpanded)';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                &exclude($loopfile, '.');
                &expand_escapes(($newnameexpanded = $newname), $loopfile);
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                $scr->cooked() unless $clobber;
                eval ($command) and
                    $scr->raw()->at(0,0)->clreol(),&display_error($!);
                $scr->raw() unless $clobber;
                $do_a_refresh = $R_SCREEN;
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
#        &expand_escapes($command, $loopfile);
        &expand_escapes(($newnameexpanded = $newname), $loopfile);
        $scr->cooked() unless $clobber;
        eval ($command) and do {
                $scr->raw()->at(0,0)->clreol();
                &display_error($!);
                &path_info;
                $do_a_refresh = $R_HEADER;
        };
        $scr->raw() unless $clobber;
    }
    return $do_a_refresh;
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
    %currentfile = %$file;
    &copyback($currentfile{name});
    &highlightline($HIGHLIGHT_OFF);
    &mark_info(%selected_nr_of);
    return $R_KEY;
}

sub validate_position {
    # requirement: $showncontents[$currentline+$baseindex] is defined
    my $redraw = $R_KEY;
    if ( $currentline < 0 ) {
        $baseindex += $currentline;
        $baseindex   < 0 and $baseindex = 0;
        $currentline = 0;
        $redraw = $R_DIRLISTING;
    }
    if ( $currentline > $screenheight ) {
        $baseindex  += $currentline - $screenheight;
        $currentline = $screenheight;
        $redraw = $R_DIRLISTING;
    }
    if ( $currentline + $baseindex > $#showncontents ) {
        $currentline = $#showncontents - $baseindex;
        $redraw = $R_DIRLISTING;
    }
    return $redraw;
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
    return $R_DIRLISTING;
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
    return &validate_position;
}

sub handleenter {
    $scr->cooked()->clrscr();
    system "./$currentfile{name}" and &display_error($!);
    &pressanykey;
    return $R_CLEAR;
}

sub handleswap {
    my $refresh     = $R_KEY;
    my $temp_state  = $swap_state;
    my $stateprompt = 'Directory Pathname: ';
    my $nextdir;
    if ($swap_state and !$swap_persistent) { # swap back if ok_to_remove_marks
        if (&ok_to_remove_marks) {
            $nextdir        =   $swap_state->{path};
            @dircontents    = @{$swap_state->{contents}};
            $position_at    =   $swap_state->{position};
            %disk           = %{$swap_state->{disk}};
            %selected_nr_of = %{$swap_state->{selected}};
            %total_nr_of    = %{$swap_state->{totals}};
            $multiple_mode  =   $swap_state->{multiple_mode};
            $sort_mode      =   $swap_state->{sort_mode};
            $dot_mode       =   $swap_state->{dot_mode};
            $0              =   $swap_state->{argvnull};
            $swap_mode = $swap_state = 0;
            $refresh = $R_SCREEN;
        } else { # not ok to remove marks
            $refresh = $R_KEY;
        }
    } elsif ($swap_state and $swap_persistent) { # swap persistent
        $swap_state = { path          =>   $currentdir,
                        contents      => [ @dircontents ],
                        position      =>   $currentfile{name},
                        disk          => { %disk },
                        selected      => { %selected_nr_of },
                        totals        => { %total_nr_of },
                        multiple_mode =>   $multiple_mode,
                        sort_mode     =>   $sort_mode,
                        dot_mode      =>   $dot_mode,
                        argvnull      =>   $0
                       };
        $nextdir        =   $temp_state->{path};
        @dircontents    = @{$temp_state->{contents}};
        $position_at    =   $temp_state->{position};
        %disk           = %{$temp_state->{disk}};
        %selected_nr_of = %{$temp_state->{selected}};
        %total_nr_of    = %{$temp_state->{totals}};
        $multiple_mode  =   $temp_state->{multiple_mode};
        $sort_mode      =   $temp_state->{sort_mode};
        $dot_mode       =   $temp_state->{dot_mode};
        $0              =   $temp_state->{argvnull};
        toggle($swap_mode);
        $refresh = $R_SCREEN;
    } else { # $swap_state = 0; ask and swap forward
        $swap_state = { path          =>   $currentdir,
                        contents      => [ @dircontents ],
                        position      =>   $currentfile{name},
                        disk          => { %disk },
                        selected      => { %selected_nr_of },
                        totals        => { %total_nr_of },
                        multiple_mode =>   $multiple_mode,
                        sort_mode     =>   $sort_mode,
                        dot_mode      =>   $dot_mode,
                        argvnull      =>   $0
                       };
        $swap_mode     = 1;
        $sort_mode     = $pfmrc{sortmode} || 'n';
        $multiple_mode = 0;
        $scr->at(0,0)->clreol()->cooked();
#        $scr->bold()->cyan()->puts($stateprompt)->normal(); # ornaments
        $nextdir = &readintohist(\@path_history, $stateprompt);
        &expand_escapes($nextdir, \%currentfile);
        $scr->raw();
        $position_at = '.';
        $refresh = $R_CHDIR;
    }
    if ( !&mychdir($nextdir) ) {
        $scr->at(1,0);
        &display_error("$nextdir: $!");
        $refresh = $R_CHDIR;
    } else {
        @showncontents = &filterdir(@dircontents);
    }
    &init_title($swap_mode, $uid_mode);
    return $refresh;
}

sub handleentry {
    local $_ = $_[0];
    my ($tempptr, $nextdir, $success, $direction);
    if ( /^kl|[h\e\cH]$/i ) {
        $nextdir   = '..';
        $direction = 'up';
    } else {
        $nextdir   = $currentfile{name};
        $direction = $nextdir eq '..' ? 'up' : 'down';
    }
    return $R_KEY if ($nextdir    eq '.');
    return $R_KEY if ($currentdir eq '/' && $direction eq 'up');
    return $R_KEY if ! &ok_to_remove_marks;
    $success = &mychdir($nextdir);
    if ($success && $direction =~ /up/ ) {
#        $oldcurrentdir = $currentdir;
        $position_at   = &basename($oldcurrentdir);
    } elsif ($success && $direction =~ /down/) {
#        $oldcurrentdir = $currentdir;
        $position_at   = '..';
    }
    unless ($success) {
        $scr->at(0,0)->clreol();
        &display_error($!);
        &init_header($multiple_mode);
    }
    return $success ? $R_CHDIR : $R_KEY;
}

##########################################################################
# directory browsing helper routines

sub stat_entry { # path_of_entry, selected_flag
    # the second argument is used to have the caller specify whether the
    # 'selected' field of the file info should be cleared (when reading
    # a new directory) or kept intact (when re-statting)
    my ($entry, $selected_flag) = @_;
    my ($ptr, $too_long, $target);
    my ($device, $inode, $mode, $nlink, $uid, $gid, $rdev, $size,
            $atime, $mtime, $ctime, $blksize, $blocks) = lstat $entry;
    if (!defined $user{$uid})  {  $user{$uid} = $uid }
    if (!defined $group{$gid}) { $group{$gid} = $gid }
    $ptr = { name     => $entry,         device   => $device,
             inode    => $inode,         mode     => &mode2str($mode),
             uid      => $user{$uid},    gid      => $group{$gid},
             nlink    => $nlink,         rdev     => $rdev,
             size     => $size,          atime    => $atime,
             mtime    => $mtime,         ctime    => $ctime,
             blksize  => $blksize,       blocks   => $blocks,
             selected => $selected_flag
            };
    $ptr->{type}     = substr($ptr->{mode},0,1);
    $ptr->{target}   = $ptr->{type} eq 'l' ? ' -> '.readlink($ptr->{name}) : '';
    $ptr->{display}  = $entry . $ptr->{target};
    $ptr->{too_long} = length($ptr->{display})>$maxfilenamelength ? '+' : ' ';
    $total_nr_of{ $ptr->{type} }++; # this is wrong! e.g. after cOmmand
    if ($ptr->{type} =~ /[bc]/) {
        $ptr->{size} = sprintf("%d",$rdev/256).$MAJORMINORSEPARATOR.($rdev%256);
    }
    return $ptr;
}

sub getdircontents { # (current)directory
    my (@contents, $entry);
    my @allentries = ();
    &init_header($multiple_mode);
    &init_title($swap_mode, $uid_mode);
    if ( opendir CURRENT, "$_[0]" ) {
        @allentries = readdir CURRENT;
        closedir CURRENT;
    } else {
        $scr->at(0,0)->clreol();
        &display_error("Cannot read . : $!");
        &init_header($multiple_mode);
    }
    # next lines also correct for directories with no entries at all
    # (this is sometimes the case on NTFS filesystems: why?)
    if ($#allentries < 0) {
        @allentries = ('.', '..');
    }
    if ($#allentries > $SLOWENTRIES) {
        # don't use display_error here because that would just cost more time
        $scr->at(0,0)->clreol()->cyan()->bold()->puts('Please Wait')->normal();
    }
    foreach $entry (@allentries) {
        # have the mark cleared on first stat with ' '
        push @contents, &stat_entry($entry,' ');
    }
    return @contents;
}

sub printdircontents { # @contents
    foreach my $i ($baseindex .. $baseindex+$screenheight) {
        unless ($i > $#_) {
            $scr->at($i+$BASELINE-$baseindex,0)->puts(&fileline(%{$_[$i]}));
            &applycolor($i+$BASELINE-$baseindex, $SHOWSHORT, %{$_[$i]});
        } else {
            $scr->at($i+$BASELINE-$baseindex,0)
                ->puts(' 'x($screenwidth-$DATECOL-1));
        }
    }
}

sub countdircontents {
    %total_nr_of    =
    %selected_nr_of =( d=>0, l=>0, '-'=>0, D=>0, bytes=>0,
                       c=>0, b=>0, 's'=>0, p=>0 );
    foreach my $i (0..$#_) {
        $total_nr_of   {$_[$i]{type}}++;
        $selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
    }
}

sub get_filesystem_info {
    my (@dflist, %tdisk);
    # maybe this should sometime be altered to run "bdf" on HP-UX
    chop( (undef, @dflist) = (`df -k .`, '') ); # undef to swallow header
    $dflist[0] .= $dflist[1]; # in case filesystem info wraps onto next line
    @tdisk{qw/device total used avail/} = split ( /\s+/, $dflist[0] );
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
    $0 = 'pfm [on ' . ( $disk{device} eq 'none' ? $disk{mountpoint}
                                                : $disk{device} ) . ']';
}

sub resizecatcher {
    $wasresized = 1;
    $SIG{WINCH} = \&resizecatcher;
}

sub resizehandler {
    $wasresized = 0;
    &handlefit;         # returns R_SCREEN, which is correct...
    &validate_position; # ... but we must validate the cursor position too
    return $R_CLEAR;
}

sub recalc_ptr {
    $position_at = '.';
    return &position_cursor; # refresh flag
}

sub redisplayscreen {
    &init_frame($multiple_mode, $swap_mode, $uid_mode);
    &path_info;
    &disk_info(%disk);
    &dir_info(%total_nr_of);
    &mark_info(%selected_nr_of);
    &user_info;
    &date_info($DATELINE,$screenwidth-$DATECOL);
}

##########################################################################
# directory browsing main routine
#
# this sub is called every time a new directory is entered.
# it is the heart of pfm. it has the following structure:
#
# sub {
#                  get filesystem info;
#   DIRCONTENTS :  read directory contents;
#   SCREEN      :  show title, footer and stats;
#   DIRLISTING  :  display directory contents;
#   STRIDE      :  wait for key;
#   KEY         :  call key command handling subroutine;
#                  jump to redo point (using R_*);
#   (R_CHDIR)   :
#   (R_QUIT)    :
# }
#
# jumps to redo points have been implemented using do..until loops.
# when a key command handling sub exits, browse() uses its return value to
# decide which redo point to jump to.
# the higher the return value, the more redrawing should be done on-screen,
# and the more loops should be exited from.
# the following are valid return values, in increasing order of severity:
#
# $R_KEY         == 0;   # no special action, wait for new key
# $R_HEADER      == 1;   # just call init_header()
# $R_STRIDE      == 2;   # wait for new keypress
# $R_DIRLISTING  == 3;   # init @showncontents from @dircontents; redisplay list
# $R_SCREEN      == 4;   # redraw entire screen
# $R_CLEAR       == 5;   # like R_SCREEN, but clrscr() first
# $R_DIRCONTENTS == 6;   # reread directory contents
# $R_CHDIR       == 7;   # exit from directory
# $R_QUIT        == 255; # exit from program

sub browse {
    my ($key, $result);
    # collect info
    $currentdir = getcwd();
    %disk       = &get_filesystem_info;
    &set_argv0;
    DIRCONTENTS: do {
        %total_nr_of    = ( d=>0, l=>0, '-'=>0, c=>0, b=>0, 's'=>0, p=>0, D=>0);
        %selected_nr_of = ( d=>0, l=>0, '-'=>0, c=>0, b=>0, 's'=>0, p=>0, D=>0,
                            bytes=>0 );
        @showncontents = &filterdir(
            @dircontents = sort as_requested &getdircontents($currentdir)
        );
        SCREEN: do {
            &redisplayscreen;
            &position_cursor if $position_at ne '';
            &recalc_ptr unless defined $showncontents[$currentline+$baseindex];
            DIRLISTING: do {
                &printdircontents(@showncontents = &filterdir(@dircontents));
#                $scr->flush_input();
                STRIDE: do {
                    %currentfile = %{$showncontents[$currentline+$baseindex]};
                    &highlightline($HIGHLIGHT_ON);
                    $result = $R_KEY;
                    until ($scr->key_pressed(1) || $wasresized) {
                        &date_info($DATELINE, $screenwidth-$DATECOL);
                        $scr->at($currentline+$BASELINE, 0);
                    }
                    if ($wasresized) { # the terminal was resized
                        $result = &resizehandler;
                    # the next line contains an assignment on purpose
                    } elsif ($scr->key_pressed() and $key = $scr->getch()) {
                        &highlightline($HIGHLIGHT_OFF);
                        KEY: for ($key) {
                        /^(?:kr|kl|[hl\e\cH])$/i
                                   and $result = &handleentry($_),     last KEY;
                        /^[cr]$/i  and $result = &handlecopyrename($_),last KEY;
                        /^[yo]$/i  and $result = &handlecommand($_),   last KEY;
                        /^e$/i     and $result = &handleedit,          last KEY;
                        /^(?:ku|kd|pgup|pgdn|[-+jk\cF\cB\cD\cU]|home|end)$/i
                                   and $result = &handlemove($_),      last KEY;
                        /^[\cE\cY]$/
                                   and $result = &handlescroll($_),    last KEY;
                        /^ $/      and $result = &handleadvance($_),   last KEY;
                        /^d$/i     and $result = &handledelete,        last KEY;
                        /^[ix]$/i  and $result = &handleinclude($_),   last KEY;
                        /^[s\r]$/i and $result = &handleshowenter($_), last KEY;
                        /^k7$/     and $result = &handleswap,          last KEY;
                        /^k5$/     and $result = &handlerefresh,       last KEY;
                        /^k3$/     and $result = &handlefit,           last KEY;
                        /^k10$/    and $result = &handlemultiple,      last KEY;
                        /^m$/i     and $result = &handlemore,          last KEY;
                        /^p$/i     and $result = &handleprint,         last KEY;
                        /^v$/i     and $result = &handleview,          last KEY;
                        /^k8$/     and $result = &handleselect,        last KEY;
                        /^t$/i     and $result = &handletime,          last KEY;
                        /^a$/i     and $result = &handlechmod,         last KEY;
                        /^q$/i     and $result = &handlequit($_),      last KEY;
                        /^k6$/     and $result = &handlesort,          last KEY;
                        /^[\/f]$/i and $result = &handlefind,          last KEY;
                        /^(?:k1|\?)$/
                                   and $result = &handlehelp,          last KEY;
                        /^k2$/     and $result = &handlecdold,         last KEY;
                        /^\.$/     and $result = &handledot,           last KEY;
                        /^k9$/     and $result = &handlecolumns,       last KEY;
                        /^k4$/     and $result = &handlecolor,         last KEY;
                        /^\@$/     and $result = &handleperlcommand,   last KEY;
                        /^u$/i     and $result = &handlechown,         last KEY;
                        /^z$/i     and $result = &handlesize,          last KEY;
                        } # end KEY
                    } # end if $key
                    if ($result == $R_HEADER) { &init_header($multiple_mode) }
                } until ($result > $R_STRIDE);
                # end STRIDE
            } until ($result > $R_DIRLISTING);
            # end DIRLISTING
            if ($result == $R_CLEAR) { $scr->clrscr }
        } until ($result > $R_CLEAR);
        # end SCREEN
    } until ($result > $R_DIRCONTENTS);
    # end DIRCONTENTS
    return $result == $R_QUIT;
} # end sub browse

##########################################################################
# void main (void)

&globalinit;
until (&browse) { $multiple_mode = 0 };
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
## General

## specify your favorite editor. you can also use $EDITOR for this
editor:vi
## your pager. you can also use $PAGER
#pager:less
## your system's print command. Specify if the default 'lpr' does not work.
#printcmd:lp -d$ENV{PRINTER}
## your system's du(1) command. Specify so that the outcome is in bytes, e.g.:
## AIX,BSD,Tru64: du -sk | awk '{printf "%d", 1024 * $1}'
## Sun          : du -s  | awk '{printf "%d", 1024 * $1}'
## HP-UX        : du -s  | awk '{printf "%d", 512  * $1}' # assume bs=512 :(
## Linux        : du -sb
ducmd:du -sk | awk '{printf "%d", 1024*$1}'

## the erase character for your terminal (default: don't set)
#erase:^H
## the keymap to use in readline (vi,emacs). (default emacs)
#keymap:vi

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
copyrightdelay:0.2
## use very visible cursor (e.g. block cursor on 'linux' type terminal)
cursorveryvisible:yes
## hide dot files? (show them otherwise, toggle with . key)
#dotmode:yes
## F7 key swap path method is persistent? (default no)
#persistentswap:yes
## show whether mandatory locking is enabled (e.g. -rw-r-lr-- ) (yes,no,sun)
## 'sun' = show locking only on sunos/solaris
showlock:sun
## initial sort mode (see F6 command) (nNmMeEfFsSiItTdDaA) (default n)
sortmode:n
## format for time: touch MMDDhhmm[[CC]YY][.ss] or pfm [[CC]YY]MMDDhhmm[.ss]
timeformat:pfm
## translate spaces when Viewing
translatespace:no
## initial title bar mode (F9 command) (mtime,uid,atime) (default mtime)
uidmode:mtime
## base number system to View non-ascii characters with (hex,oct)
viewbase:hex

##########################################################################
## Colors

## use color (yes,no,force)
## 'no'    = use no color at all
## 'yes'   = use color for title bars, if your terminal supports it
## 'force' = use color for title bars on any terminal
## your *files* will only be colored if you also define 'dircolors' below
usecolor:force

## 'dircolors' defines the colors that will be used for your files.
## for your files to become colored, you must set 'usecolor' to 1.
## see also the manpages for ls(1) and dircolors(1L) (on Linux systems).
## you can also use $LS_COLORS or $LS_COLOURS to set this.

##-attribute codes:
## 00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed(?)
##-text color codes:
## 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
##-background color codes:
## 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white
##-file types:
## no=normal fi=file di=directory ln=symlink pi=fifo so=socket bd=block special
## cd=character special or=orphan link mi=missing link ex=executable
## *.<ext> defines extension colors

## you may specify the escape as a real escape, as \e or as ^[ (caret, bracket)

dircolors:no=00:fi=00:di=01;34:ln=01;36:pi=00;40;33:so=01;35:bd=40;33;01:\
cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:ex=00;32:lc=^[[:rc=m:\
*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:*.pas=32:\
*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:\
*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.rpm=31:*.pm=00;36:*.pl=00;36:\
*.jpg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:\
*.mpg=01;37:*.avi=01;37:*.gl=01;37:*.dl=01;37:*.htm=01;33:*.html=01;33

## use this if you want no colors for your files, but only for the title bars
#dircolors:-

## colors for header, title, footer
## regardless of these settings, the footer will always be bold
## these are commented out because they are the defaults
#headercolor:37;44
#multicolor:36;47
#titlecolor:36;47;07;01
#swapcolor:36;40;07
#footercolor:34;47;07

##########################################################################
## Your commands

## these assume you do not have filenames with double quotes in them

B:xv -root +noresetroot +smooth -maxpect -quit "\2"
C:tar cvf - "\2" | gzip > "\2".tar.gz
D:uudecode "\2"
E:unarj l "\2" | more
F:file "\2"
G:gvim "\2"
I:rpm -qpi "\2"
J:mpg123 "\2" &
L:mv -i "\2" "`echo \"\2\" | tr A-Z a-z`"
N:nroff -man "\2" | more
P:perl -cw "\2"
Q:unzip -l "\2" | more
R:rpm -qp -l "\2" | more
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
# Pod Documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [>I<directory>C<]>

=head1 DESCRIPTION

C<pfm> is a terminal-based file manager, based on PFMS<.>COM for MS-DOS.

All C<pfm> commands are one- or two-letter commands (nearly all of
which are case-insensitive).  C<pfm> can operate in single-file mode or
multiple-file mode.  In single-file mode, the command corresponding to
the keypress will be performed on the file next to the cursor only. In
multiple-file mode, the command will apply to all files which the user
has previously marked.  See FUNCTION KEYS below for the relevant commands.

Note that throughout this manual page, I<file> can mean any type
of file, not just plain regular files. These will be referred to as
I<regular files>.

=head1 OPTIONS

=over

You may specify a starting directory on the command line when
invoking C<pfm>. The C<CDPATH> environment variable is taken into
account C<pfm> tries to find this directory. There are no command line
options. Configuration is read from a file, F<$HOME/.pfm/.pfmrc> , which
is created automatically the first time you start C<pfm>. The file is
supposed to be self-explanatory.  See also MORE COMMANDS below.

=back

=head1 NAVIGATION

=over

Navigation through directories is done using the arrow keys, the C<vi>(1)
cursor keys (B<hjkl>), B<->, B<+>, B<PgUp>, B<PgDn>, B<home>, B<end>,
and the C<vi>(1) control keys B<CTRL-F>, B<CTRL-B>, B<CTRL-U>, B<CTRL-D>,
B<CTRL-Y> and B<CTRL-E>.  Pressing B<ESC> or B<BS> will take you one
directory level up (note: see BUGS below). Pressing B<ENTER> when the
cursor is on a directory will take you into the directory. Pressing
B<SPACE> will both mark the current file and advance the cursor.

=back

=head1 COMMANDS

=over

=item B<.>

Toggle show/hide dot files.

=item B</>

Identical to B<F>ind (see below).

=item B<?>

Display help. Identical to B<F1>.

=item B<@>

Allows the user to enter a perl command to be executed in the context
of C<pfm>. Primarily used for debugging.

=item B<Attr>

Changes the mode of the file if you are the owner. Use a '+' to add
a permission, a '-' to remove it, and a '=' specify the mode exactly,
or specify the mode numerically. Note that the mode on a symbolic link
cannot be set. Read the C<chmod>(1) page for more details.

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
else C<vi>(1) is used.

=item B<Find>

Prompts for a filename, then positions the cursor on that file.

=item B<Include>

Allows you to mark a group of files which meet a certain criterion:
B<E>very file, B<O>ldmarks (reselects any files which were previously
marked and are now denoted with an I<oldmark> B<.> ), B<U>ser (only
files owned by you) or B<F>iles only (prompts for a regular expression
(not a glob pattern) which the filename must match). Oldmarks may be
used to do multifile operations on a group of files more than once. If
you B<I>nclude B<E>very, dotfiles will be included as well, except for
the B<.> and B<..> directory entries.

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
C<pfm> should ask for confirmation (option 'confirmquit').  Note that
by pressing a capital Q (quick quit), you will I<never> be asked for
confirmation. This is in fact the one case-sensitive command.

=item B<Rename>

Change the name of the file to the path- and filename specified. Depending
on your Unix implementation, a different path- and filename on another
filesystem may or may not be allowed. In multiple-file mode, the new
name I<must> be a directoryname or a name containing a B<\1> or B<\2>
escape (see cB<O>mmand above). If the option I<clobber> is set to I<no>
in F<$HOME/.pfm/.pfmrc>, existing files will not be overwritten unless
the action is confirmed by the user.

=item B<Show>

Displays the contents of the current file or directory on the screen.
You can choose which pager to use for file viewing with the environment
variable C<PAGER>, or in the F<$HOME/.pfm/.pfmrc> file.

=item B<Time>

Change mtime (modification date/time) of the file. The format used is
converted to a format which C<touch>(1) can use. Enter B<.> to set the
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

Displays the size (in bytes) of the file, or the grand total of the
directory and its contents.  Note that since C<du>(1) is not portable,
you will have to specify the C<du> command (or C<du | awk> combination)
applicable for your Unix version in the F<.pfmrc> file. Examples are
provided.

=back

=head1 MORE COMMANDS

=over

=item B<Config PFM>

This option will open the F<$HOME/.pfm/.pfmrc> configuration file with
your preferred editor. The file is re-read by C<pfm> after you exit
your editor.

=item B<Edit new file>

You will be prompted for the new filename, then your editor will
be spawned.

=item B<Make new directory>

Specify a new directory name and C<pfm> will create it for you.
Furthermore, if you don't have any files marked, your current
directory will be set to the newly created directory.

=item B<Show new directory>

You will have to enter the new directory you want to view. Just pressing
B<ENTER> will take you to your home directory. Be aware that this option
is different from B<F7> because this will not change your current swap
directory status.

=item B<sHell>

Spawns your default login shell until you exit from it, then resumes.

=item B<Kill children>

Lists available signals. After selection of a signal, sends this signal
to all child processes of C<pfm> (more accurately: all processes in the
same process group).

=item B<Write history>

C<pfm> uses the readline library for keeping track of the Unix commands,
pathnames, regular expressions, mtimes, and file modes entered. The
history is read from individual files in F<$HOME/.pfm/> every time
C<pfm> starts. The history is written only when this command is given,
or when C<pfm> exits and the 'autowritehistory' option is set in
F<$HOME/.pfm/.pfmrc> .

=back

=head1 MISCELLANEOUS and FUNCTION KEYS

=over

=item B<F1>

Display help, version number and license information.

=item B<F2>

Jump back to the previous directory.

=item B<F3>

Fit the file list into the current window and refresh the display. C<pfm>
attempts to refresh the display when the window size changes, but should
this fail, then press B<F3>.

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

Toggle the display mode between either user id, group id, and link count,
or date, time, and inode number.

=item B<F10>

Switch between single-file and multiple-file mode.

=item B<ENTER>

Displays the contents of the current file or directory on the screen.
If the current file is executable, the executable will be invoked.

=back

=head1 WORKING DIRECTORY INHERITANCE

=over

Upon exit, C<pfm> will save its current working directory in a file
F<$HOME/.pfm/cwd> . In order to have this directory "inherited" by the
calling process (shell), you may call C<pfm> using a function like the
following (example for C<bash>(1), add it to your F<.profile>):

 pfm () {
     /usr/local/bin/pfm $*
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

The directory where the B<M>ore - B<S>how new dir and B<F7> commands
will take you if you don't specify a new directory.

=item B<PAGER>

Identifies the pager with which to view text files. Defaults to C<less>(1)
for Linux systems or C<more>(1) for Unix systems.

=item B<PRINTER>

May be used to specify a printer to print to using the B<P>rint command.

=item B<SHELL>

Your default login shell, spawned by cB<O>mmand when an empty line is
entered.

=back

=head1 FILES

The directory F<$HOME/.pfm/> and files therein. Several input histories
are saved to this directory.

=head1 BUGS and WARNINGS

When typed by itself, the B<ESC> key needs to be pressed twice. This is
due to the lack of a proper timeout in C<Term::Screen>.

In order to allow spaces in filenames, several commands assume they can
safely surround filenames with double quotes. This prevents the correct
processing of filenames containing double quotes.

The F<readline> library does not allow a half-finished line to be
aborted by pressing B<ESC>. For most commands, you will need to clear
the half-finished line.

Sometimes when key repeat sets in, not all keypress events have been
processed, although they have been registered. This can be dangerous when
deleting files.  The author once almost pressed ENTER when logged in as
root and with the cursor next to F</sbin/reboot> . You have been warned.

=head1 VERSION

This manual pertains to C<pfm> version 1.61 .

=head1 SEE ALSO

The documentation on PFMS<.>COM . The mentioned manual pages for
C<chmod>(1), C<less>(1), C<lpr>(1), C<touch>(1). The manual pages for
C<Term::ScreenColor>(3) and C<Term::ReadLine::Gnu>(3).

=head1 AUTHOR

Written by RenE<eacute> Uittenbogaard (ruittenb@users.sourceforge.net).
This program was based on PFMS<.>COM version 2.32, originally written
for MS-DOS by Paul R. Culley and Henk de Heer. Permission to use the
name 'pfm' was granted by Henk de Heer.

=head1 COPYRIGHT

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

=cut

# vi: set tabstop=4 shiftwidth=4 expandtab list foldmethod=indent nofoldenable:

