#!/usr/local/bin/perl
#
##########################################################################
# @(#) pfm.pl 2001-04-10 v1.44
#
# Name:        pfm.pl
# Version:     1.44
# Author:      Rene Uittenbogaard
# Date:        2001-04-10
# Usage:       pfm.pl [directory]
# Requires:    Term::ScreenColor
#              Term::Screen
#              Term::Cap
#              Term::ReadLine::Gnu
#              Term::ReadLine
#              Cwd
#              strict
#              vars
#              warnings
#              diagnostics
# Description: Personal File Manager for Unix/Linux
#
# TO-DO:
# first: neaten \n in all commands (Y/O/...), and in history, and in historyfile
#        jump back to old current dir with F2: debug for F7 and > $#dircontents
#        change F2 to use @old_cwd_at
#        test pfm with -w
#        \5 should work in multiple copy/rename
#        More -> Kill all child processes?
#        handleinclude can become faster with &$bla; instead of eval $bla;
# next:  clean up configuration options (yes/no,1/0,true/false)
#        validate_position should not replace $baseindex when not necessary
#        stat_entry() must *not* rebuild the selected_nr and total_nr lists:
#            this fucks up with e.g. cOmmand -> cp \2 /somewhere/else
#            closely related to:
#        sub countdircontents is not used
#        consistent use of constants
#        neaten use of spaces in source
#        cOmmand -> rm \2 will have to delete the entry from @dircontents;
#            otherwise the mark count is not correct
#
#        siZe command?
#        major/minor numbers on DU 4.0E are wrong
#        tidy up multiple commands
#        validate_position in SIG{WINCH}
#        key response (flush_input)
#        rename: restat file under new name?
#        we might someday use the 'constant' pragma
# terminal:
#        intelligent restat (changes in current dir?)
# licence

##########################################################################
# Main data structures:
#
# @dircontents   : array (current directory data) of pointers (to file data)
# $dircontents[$index]      : pointer (to file data) to hash (file data)
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
    $R_QUITTING
);

BEGIN {
    $ENV{PERL_RL} = 'Gnu ornaments=0';
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
*R_QUITTING    = \255;

my $VERSION             = &getversion;
my $CONFIGDIRNAME       = "$ENV{HOME}/.pfm";
my $CONFIGFILENAME      = '.pfmrc';
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

my @command_history = qw(true);
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

my (%user, %group, %pfmrc, %dircolors, $maxfilenamelength, $wasresized,
    $scr, $kbd,
    $uidlineformat, $tdlineformat, $timeformat,
    $sort_mode, $multiple_mode, $uid_mode, $swap_mode,
    $swap_persistent, $swap_state,
    $currentdir, @dircontents, %currentfile, $currentline, $baseindex,
    $oldcurrentdir, %disk, %total_nr_of, %selected_nr_of,
    $editor, $pager, $printcmd, $showlockchar, $autoexitmultiple,
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
            s/^(# Version )x$/$1$VERSION/m;
            s/^([A-Z]:\w+.*?\s+)more(\s*)$/$1less$2/mg if $^O =~ /linux/i;
            $_;
        } @resourcefile;
        close MKPFMRC;
    }
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
    if (defined($pfmrc{usecolor}) && !$pfmrc{usecolor}) {
        $scr->colorizable($FALSE);
    } elsif (defined($pfmrc{usecolor}) && ($pfmrc{usecolor}==2)) {
        $scr->colorizable($TRUE);
    }
    &copyright($pfmrc{copyrightdelay}) unless ($_[0]);
    system ('tput', $pfmrc{cursorveryvisible} ? 'cvvis' : 'cnorm');
    system ('stty', 'erase', $pfmrc{erase}) if defined($pfmrc{erase});
    $kbd->set_keymap($pfmrc{keymap})        if $pfmrc{keymap};
    $autoexitmultiple = $pfmrc{autoexitmultiple};
    # note: some configuration options are NOT fetched into common scalars -
    # they remain accessable in %pfmrc (e.g. autowritehistory)
    ($printcmd)       = ($pfmrc{printcmd}) ||
                            ($ENV{PRINTER} ? "lpr -P$ENV{PRINTER}" : 'lpr');
    $timeformat       = $pfmrc{timeformat} || 'pfm';
    $sort_mode        = $pfmrc{sortmode}   || 'n';
    $uid_mode         = $pfmrc{uidmode};
    $swap_persistent  = $pfmrc{persistentswap};
    $headercolor      = $pfmrc{headercolor} || '37;44';
    $multicolor       = $pfmrc{multicolor}  || '36;47';
    $titlecolor       = $pfmrc{titlecolor}  || '36;47;07;01';
    $swapcolor        = $pfmrc{swapcolor}   || '36;40;07';
    $footercolor      = $pfmrc{footercolor} || '34;47;07';
    $showlockchar     = ($pfmrc{showlock} eq 'sun' && $^O =~ /sun|solaris/i
                            or $pfmrc{showlock} eq 'yes') ? 'l' : 'S';
    $editor           = $ENV{EDITOR} || $pfmrc{editor} || 'vi';
    $pager            = $ENV{PAGER}  || $pfmrc{pager}  ||
                            ($^O =~ /linux/i ? 'less' : 'more');
    $pfmrc{dircolors} ||= $ENV{LS_COLORS} || $ENV{LS_COLOURS};
    if ($pfmrc{dircolors}) {
        while ($pfmrc{dircolors} =~ /([^:=*]+)=([^:=]+)/g ) {
            $dircolors{$1}=$2;
        }
    }
}

sub write_history {
    my $failed;
    foreach (keys(%HISTORIES)) {
        if (open (HISTFILE, ">$CONFIGDIRNAME/$_")) {
            print HISTFILE join "\n",@{$HISTORIES{$_}};
            close HISTFILE;
        } elsif (!$failed) {
            $scr->at(0,0)->puts("Unable to save (part of) history: $!\n");
            # wait? refresh?
            $failed++; # warn only once
        }
    }
}

sub read_history {
    foreach (keys(%HISTORIES)) {
        if (open (HISTFILE, "$CONFIGDIRNAME/$_")) {
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
        # pfm is exiting, can use warn() here
        warn "pfm: unable to create $CONFIGDIRNAME/$CWDFILENAME: $!\n";
    }
}

##########################################################################
# some translations

sub getversion {
    my $ver = '?';
    if ( open (SELF, $0) || open (SELF, `which $0`) ) {
        foreach (grep /^# Version:/, <SELF>) {
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
    return \%user;
}

sub init_gids {
    my (%group, $name, $gid);
    while (($name, undef, $gid) = getgrent) {
        $group{$gid} = $name
    }
    endgrent;
    return \%group;
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
    my $nummode  = shift;
    my $octmode  = sprintf("%lo", $nummode);
    my @strmodes = (qw/--- --x -w- -wx r-- r-x rw- rwx/);
    $octmode     =~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
    $strmode     = substr('?pc?d?b?-?l?s?=D=?=?d', oct($1), 1)
                 . $strmodes[$3] . $strmodes[$4] . $strmodes[$5];
                 # first  d for Linux, OSF1, Solaris
                 # second d for AIX
    if ($2 & 4) {       substr( $strmode,3,1) =~ tr/-x/Ss/ }
    if ($2 & 2) { eval "substr(\$strmode,6,1) =~ tr/-x/${showlockchar}s/" }
    if ($2 & 1) {       substr( $strmode,9,1) =~ tr/-x/Tt/ }
    return $strmode;
}

sub fit2limit {
    my $neatletter = '';
    my $neatsize = $_[0];
    my $LIMIT = 9_999_999;
    while ( $neatsize > $LIMIT ) {
        $neatsize = int($neatsize/1024);
        $neatletter =~ tr/KMGT/MGTP/ || do { $neatletter = 'K' };
#        $LIMIT = 999_999;
    }
    return ($neatsize, $neatletter);
}

sub expand_escapes {
    my %thisfile = %{$_[1]};
    my $namenoext =
        $thisfile{name} =~ /^(.*)\.([^\.]+)$/ ? $1 : $thisfile{name};
    # these (hairy) regexps use a negative lookbehind assertion:
    # count the nr. of backslashes before the \1 (must be odd
    # because \\ must be interpreted as an escaped backslash)
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\1/$1$namenoext/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\2/$1$thisfile{name}/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\3/$1$currentdir/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\4/$1$disk{mountpoint}/g;
    $_[0] =~ s/((?<!\\)(?:\\\\)*)\\5/$1$swap_state->{path}/g if $swap_state;
    $_[0] =~ s/\\\\/\\/g;
}

sub readintohist { # \@history
    local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
    local $^W       = 0;        # Term::Readline::Gnu is not -w proof
    my ($history)   = @_;
    my $input       = '';
    $kbd->SetHistory(@$history);
    $input = $kbd->readline();  # this line barfs with -w
    if ($input =~ /\S/ and $input ne ${$history}[$#$history]) { # this too ...
        push (@$history, $input);
        shift (@$history) if ($#$history > $MAXHISTSIZE);
    }
    return $input;
}

sub max ($$) {
    return ($_[1] > $_[0]) ? $_[1] : $_[0];
}

sub min ($$) {
    return ($_[1] < $_[0]) ? $_[1] : $_[0];
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
    $_[0] =~ /\/([^\/]*)$/; # ok, we suffer LTS but this looks better in vim
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

##########################################################################
# apply color

sub digestcolor {
    return unless defined $_[0];
    foreach (split /;/,$_[0]) { $scr->color($_) }
}

sub decidecolor {
    my %file=@_;
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
    my $elision      = '..';
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
            $restpathlen = $maxpathlen -length($disppath) -length($elision) -1;
            unless ($path =~ /(\/.{1,$restpathlen})$/) {
                # impossible to replace; just truncate
                # this is the case for e.g. /usr/someinsanelylongdirectoryname
                $disppath = substr($disppath.$path, 0, $maxpathlen);
                $overflow = '+';
                last FIT;
            }
            # pathname component candidate for replacement found; name will fit
            $disppath .= $elision . $1;
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
#    my $neatsize = &fit2limit($specs{size});
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
    my $wildfilename;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts("Wild filename (regular expression): ")->normal()->cooked();
    $wildfilename = &readintohist(\@regex_history);
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
Attr Time Copy Del Edit Find Print Rename Show Uid View Your cOmmand Quit More  
Multiple Include eXclude Attribute Time Copy Delete Print Rename Your cOmmands  
Include? Every, Oldmarks, User or Files only:                                   
Config PFM Edit new file Make new dir Show dir Write history ESC to mainmenu    
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
    chop($footer=<<_eoFunction_);
F1-Help F2-Back F3-Fit F4-Color F5-Read F6-Sort F7-Swap F8-Incl F9-Uid F10-Multi
_eoFunction_
    &digestcolor($footercolor);
    $scr->reverse() if ($footercolor =~ /\b0?7\b/);
    $scr->bold()->at($BASELINE+$screenheight+1,0)
        ->puts($footer.' 'x($screenwidth-80))->normal();
}

sub copyright {
    $scr->cyan()->puts("PFM $VERSION for Unix computers and compatibles.")
        ->at(1,0)->puts("Copyright (c) 1999-2001 Rene Uittenbogaard")
        ->at(2,0)->puts("This software comes with no warranty: see the file "
                       ."COPYING for details.")->normal();
    return $scr->key_pressed($_[0]);
}

sub globalinit {
    $SIG{WINCH} = sub { $wasresized = 1 };
    $scr = Term::ScreenColor->new();
    $scr->clrscr();
    $kbd = Term::ReadLine->new('Pfm', \*STDIN, \*STDOUT);
    &read_pfmrc($FIRSTREAD);
    &read_history;
    %user  = %{&init_uids};
    %group = %{&init_gids};
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
    $oldcurrentdir = getcwd();
    $ARGV[0] and chdir($ARGV[0]) || do {
        $scr->at(0,0)->clreol();
        &display_error("$ARGV[0]: $! - using .");
        $scr->key_pressed(1); # add another second error delay
        &init_header($SINGLEHEADER);
    };
}

sub goodbye {
    my $bye = 'Goodbye from your Personal File Manager!';
    if ($pfmrc{clsonexit}) {
        $scr->clrscr();
    } else {
        $scr->at(0,0)->puts(' 'x(($screenwidth-length $bye)/2).$bye)->clreol()
            ->normal()->at($screenheight+$BASELINE+1,0)->clreol()->cooked();
    }
    &write_cwd;
    &write_history if $pfmrc{autowritehistory};
    system ('tput','cnorm') if $pfmrc{cursorveryvisible};
}

sub credits {
    $scr->clrscr()->cooked();
    print <<"_eoCredits_";


             PFM for Unix computers and compatibles.  Version $VERSION
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-2001 Rene Uittenbogaard


       PFM is distributed under the GNU General Public License version 2.
                    PFM is distributed without any warranty,
             even without the implied warranties of merchantability
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.


      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to update this product.


     For questions/remarks about PFM, or just to tell me you are using it,
                        send email to: ruittenb\@wish.nl


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
    my @desc=('K tot','K usd','K avl');
    my @values=@disk{qw/total used avail/};
    my $startline=4;
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
    my @desc=qw/files dirs symln spec/;
    my @values=@total_nr_of{'-','d','l'};
    $values[3] = $total_nr_of{'c'} + $total_nr_of{'b'}
               + $total_nr_of{'p'} + $total_nr_of{'s'}
               + $total_nr_of{'D'};
    my $startline = 9;
    $scr->at($startline-1, $screenwidth-$DATECOL+2)
        ->puts("Directory($sort_mode)");
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
    my ($line, $col)=@_;
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
    return $R_QUITTING if $pfmrc{confirmquit} =~ /never/i;
    return $R_QUITTING if $_[0] eq 'Q'; # quick quit
    return $R_QUITTING if ($pfmrc{confirmquit} =~ /marked/i and !&mark_info);
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("Are you sure you want to quit [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return +($sure =~ /y/i) ? $R_QUITTING : $R_HEADER;
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
        chdir $oldcurrentdir; # assumes this is always possible;
        # maybe make a decent &mychdir();
        $oldcurrentdir = $currentdir;
        return $R_CHDIR;
    } else {
        return $R_KEY;
    }
}

sub handlefind {
    my $findme;
    $scr->at(0,0)->clreol()->cyan()->bold()->puts("File to find: ")->normal()
        ->cooked()->at(0,14);
    ($findme = &readintohist(\@path_history)) =~ s/\/$//;
    if ($findme =~ /\//) { $findme = basename($findme) };
    $scr->raw();
    return $R_HEADER unless $findme;
    FINDENTRY:
    foreach (sort by_name @dircontents) {
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
    $scr->at(0,0)->clreol()->cyan()->bold()
        ->puts("Enter Perl command:")
        ->at(1,0)->normal()->clreol()->cooked();
    $perlcmd = &readintohist(\@perlcmd_history);
    $scr->raw();
    eval $perlcmd;
    &display_error($@) if $@;
    return $R_SCREEN;
}

sub handlemore {
    local $_;
    my $do_a_refresh = $R_SCREEN;
    my $newname;
    &init_header($MOREHEADER);
    my $key = $scr->at(0,76)->getch();
    for ($key) {
        /^s$/i and do {
            return $R_HEADER unless &ok_to_remove_marks;
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('Directory Pathname: ')->normal()
                ->cooked()->at(0,20);
            $newname = &readintohist(\@path_history);
            $scr->raw();
            $position_at='.';
            if ( !chdir $newname ) {
                &display_error("$newname: $!");
                $currentdir = getcwd();
            } else {
                $oldcurrentdir = $currentdir;
                $currentdir = $newname;
                $do_a_refresh = $R_CHDIR;
            }
        };
        /^m$/i and do {
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('New Directory Pathname: ')->normal()
                ->cooked()->at(0,24);
            $newname = &readintohist(\@path_history);
            $scr->raw();
            if ( !mkdir $newname,0777 ) {
                &display_error("$newname: $!");
            } else {
# could this be enough?
#                return $R_HEADER unless &ok_to_remove_marks;
                return $R_SCREEN unless &ok_to_remove_marks;
                $do_a_refresh = $R_CHDIR;
                if ( !chdir $newname ) {
                    &display_error("$newname: $!"); # e.g. by restrictive umask
                } else {
                    $oldcurrentdir = $currentdir;
                    $currentdir = getcwd();
                    $position_at = '.';
                }
            }
        };
        /^c$/i and do {
            if (system "$editor $CONFIGDIRNAME/$CONFIGFILENAME") {
                &display_error($!);
            } else {
                &read_pfmrc($REREAD);
            }
            $scr->clrscr();
            $do_a_refresh = $R_CLEAR;
        };
        /^e$/i and do {
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('New name: ')->normal()
                ->cooked()->at(0,10);
            $newname = &readintohist(\@path_history);
            system "$editor $newname" and &display_error($!);
            $scr->raw();
            $do_a_refresh = $R_CLEAR;
        };
        /^w$/i and do {
            &write_history;
        };
    }
    return $do_a_refresh;
}

sub handleinclude { # include/exclude flag (from keypress)
    local $_;
    my $do_a_refresh = $R_HEADER;
    my ($wildfilename, $criterion, $entry);
    my $exin = $_[0];
    &init_header($INCLUDEHEADER);
    # modify header to say "exclude" when 'x' was pressed
    if ($exin =~ /x/i) { $scr->at(0,0)->on_blue()->puts('Ex')->normal(); }
    $exin =~ tr/ix/* /;
    my $key=$scr->at(0,46)->getch();
    PARSEINCLUDE: {
        # hey Rene, look at this:
#       %age = ( bear => 56, dog => 15, snake => 4, cat => 10, horse => 70);
#       $crit = sub { $bla =~ /a/ and println $bla }
#       foreach $bla (keys %age) { &$crit; }
# cat
# snake
# bear
        for ($key) {
            /^e$/i and do {    # include every
                $criterion = '$entry->{name} !~ /^\.\.?$/';
#                $criterion = sub { $entry->{name} !~ /^\.\.?$/ };
                $key       = "prepared";
                redo PARSEINCLUDE;
            };
            /^f$/i and do {    # include files
                $wildfilename = &promptforwildfilename;
                $criterion    = '$entry->{name} =~ /$wildfilename/'
                              . ' and $entry->{type} eq "-" ';
#                $criterion    = sub {
#                                    my $wildfname = shift;
#                                    $entry->{name} =~ /$wildfname/
#                                    and $entry->{type} eq "-";
#                                };
                $key          = "prepared";
                redo PARSEINCLUDE;
            };
            /^u$/i and do { # user only
                $criterion = '$entry->{uid}' . " =~ /$ENV{USER}/";
#                $criterion = sub {
#                                 $entry->{uid} =~ /$ENV{USER}/;
#                             };
                $key       = "prepared";
                redo PARSEINCLUDE;
            };
            /^o$/i and do {   # include oldmarks
                foreach $entry (@dircontents) {
                    if ($entry->{selected} eq "." && $exin eq " ") {
                        $entry->{selected} = $exin;
                    } elsif ($entry->{selected} eq "." && $exin eq "*") {
                        &include($entry);
                    }
                    $do_a_refresh = $R_SCREEN;
                }
            };
            /prepared/ and do { # the criterion has been set
                foreach $entry (@dircontents) {
                    if (eval $criterion) {
#                    if (&$criterion($wildfilename)) {
                        if ($entry->{selected} eq "*" && $exin eq " ") {
                            &exclude($entry);
                        } elsif ($entry->{selected} eq "." && $exin eq " ") {
                            $entry->{selected} = $exin;
                        } elsif ($entry->{selected} ne "*" && $exin eq "*") {
                            &include($entry);
                        }
                        $do_a_refresh = $R_SCREEN;
                    }
                }
            };
        } # for
    } # PARSEINCLUDE
    return $do_a_refresh;
}

sub handleview {
    &markcurrentline('V');
    $scr->at($currentline+$BASELINE,2)
        ->bold()->puts($currentfile{display}.' ');
    &applycolor($currentline+$BASELINE, $SHOWLONG, %currentfile);
    $scr->normal()->getch();
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
    foreach (grep { ($i+=1)%=2 } @SORTMODES) {
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
    my $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('U') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts("New user[:group] : ")->normal()->cooked();
    chop ($newuid=<STDIN>);
    $scr->raw();
    return $R_HEADER if ($newuid eq '');
    $do_this = 'system qq/chown '.$newuid.' $loopfile->{name}/ '
             . 'and &display_error($!), $do_a_refresh = $R_SCREEN';
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile=$dircontents[$index];
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
        $loopfile=\%currentfile;
        eval($do_this);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
    }
    return $do_a_refresh;
}

sub handlechmod {
    my ($newmode,$loopfile,$do_this,$index);
    my $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts("Permissions ( [ugoa][-=+][rwxslt] or octal ): ")->normal()
        ->cooked();
    chomp($newmode = &readintohist(\@mode_history));
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
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name}, $currentfile{selected});
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
                $printstr=$pfmrc{$_};
                $printstr =~ s/\e/^[/g;
                $^A="";
                formline('@ @<<<<<<<<<<<',$_,$printstr);
                $scr->at($printline++,$screenwidth-$DATECOL)->puts($^A);
            }
        }
        $key=$scr->at(0,0)->clreol()->cyan()->bold()
                 ->puts('Enter one of the highlighted chars at right:')
                 ->at(0,45)->normal()->getch();
        &clearcolumn;
        return $R_SCREEN unless ($command = $pfmrc{uc($key)}); # assignment!
        $scr->cooked();
        $command .= "\n";
    } else { # cOmmand
        $printstr=<<'_eoPrompt_';
Enter Unix command (\1=name, \2=name.ext, \3=path, \4=mountpoint, \5=swap path):
_eoPrompt_
        $scr->at(0,0)->clreol()->bold()->cyan()->puts($printstr)->normal()
            ->at(1,0)->clreol()->cooked();
        $command = &readintohist(\@command_history);
    }
    $command =~ s/^\s*\n?$/$ENV{'SHELL'}/;
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
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &expand_escapes($command,\%currentfile);
        $scr->clrscr()->at(0,0)->puts($command);
        system ($command) and &display_error($!);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
    }
    &pressanykey;
    return $R_CLEAR;
}

sub handledelete {
    my ($loopfile,$do_this,$index,$success);
    &markcurrentline('D') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cyan()->bold()
        ->puts("Are you sure you want to delete [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return $R_HEADER if $sure !~ /y/i;
    $do_this = q"if ($loopfile->{type} eq 'd') {
                    $success=rmdir $loopfile->{name};
                 } else {
                    $success=unlink $loopfile->{name};
                 }
                 if ($success) {
                     $total_nr_of{$loopfile->{type}}--;
                     &exclude($loopfile) if $loopfile->{selected} eq '*';
                     if ($currentline+$baseindex >= $#dircontents) {
                         $currentline--; # note: see below
                     }
                     @dircontents=(
                         $index>0             ? @dircontents[0..$index-1]             : (),
                         $index<$#dircontents ? @dircontents[$index+1..$#dircontents] : ()
                     ); # splice doesn't work for me
                 } else { # not success
                     &display_error($!);
                 }
                 ";
    if ($multiple_mode) {
        # we must delete in reverse order because the number of directory
        # entries will decrease by deleting
        for $index (reverse(0..$#dircontents)) {
            $loopfile=$dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                eval($do_this);
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile=\%currentfile;
        $index=$currentline+$baseindex;
        eval($do_this);
    }
    &validate_position;
    return $R_SCREEN;
}

sub handleprint {
    my ($loopfile, $do_this, $index);
    &markcurrentline('P') unless $multiple_mode;
#    $scr->at(0,0)->clreol();
    $scr->at(0,0)->clreol()->bold()->cyan()->puts('Enter print command: ')->normal()
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
    return if $do_this eq '';
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
            $loopfile=$dircontents[$index];
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
    system ('man', 'pfm'); # how unsubtle :-)
    &credits;
    return $R_CLEAR;
}

sub handletime {
    my ($newtime, $loopfile, $do_this, $index, $do_a_refresh);
    $do_a_refresh = $multiple_mode ? $R_SCREEN : $R_HEADER;
    &markcurrentline('T') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts("Put date/time $TIMEHINTS{$timeformat}: ")->normal()->cooked();
    $newtime = &readintohist(\@time_history);
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
            $loopfile=$dircontents[$index];
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
        $loopfile=\%currentfile;
        eval($do_this);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
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
    my $statecmd = $state eq 'C' ? 'cp' : 'mv';
    my $stateprompt = $state eq 'C' ? 'Destination: ' : 'New name: ';
    my ($loopfile,$index,$newname,$command,$do_this);
    my $do_a_refresh = $R_HEADER;
    &markcurrentline($state) unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts($stateprompt)->normal()->cooked();
    $newname = &readintohist(\@path_history);
    $scr->raw();
    return $R_HEADER if ($newname eq '');
    # we would like to substitute \[345] at this point, but not yet \[\12]
    if ($multiple_mode and $newname !~ /(?<!\\)(?:\\\\)*\\[12]/
                       and !-d($newname) )
    {
        $scr->at(0,0)->cyan()->bold()
        ->puts("Cannot do multifile operation when destination is single file.")
        ->normal()->at(0,0);
        &pressanykey;
        &path_info;
        return 0; # don't refresh screen - is this correct?
    }
    $command = 'system qq{'.$statecmd.' "$loopfile->{name}" "'.$newname.'"}';
    if ($multiple_mode) {
        $scr->at(1,0)->clreol();
        for $index (0..$#dircontents) {
            $loopfile = $dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                &exclude($loopfile,'.');
                $do_this = $command;
                &expand_escapes($do_this, $loopfile);
                $scr->at(1,0)->puts($loopfile->{name});
                eval ($do_this) and $scr->at(0,0)->clreol(),&display_error($!);
                $do_a_refresh = $R_SCREEN;
            }
        }
        $multiple_mode = inhibit($autoexitmultiple, $multiple_mode);
    } else {
        $loopfile = \%currentfile;
        &expand_escapes($command,$loopfile);
        eval ($command) and do {
                $scr->at(0,0)->clreol();
                &display_error($!);
        }
    }
    return $do_a_refresh;
}

sub handleselect {
    # we cannot use %currentfile because we don't want to modify a copy
    my $file          = $dircontents[$currentline+$baseindex];
    my $was_selected  = $file->{selected} =~ /\*/;
    $file->{selected} = substr('* ',$was_selected,1);
    if ($was_selected) {
        $selected_nr_of{$file->{type}}--;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} -= $file->{size};
    } else {
        $selected_nr_of{$file->{type}}++;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} += $file->{size};
    }
    %currentfile = %$file;
    &highlightline($HIGHLIGHT_OFF);
    &mark_info(%selected_nr_of);
    return $R_KEY;
}

sub validate_position {
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
    if ( $currentline + $baseindex > $#dircontents ) {
        $currentline = $#dircontents - $baseindex;
        $redraw = $R_DIRLISTING;
    }
    return $redraw;
}

sub handlescroll {
    local $_ = $_[0];
    return 0 if (/\cE/ && $baseindex == $#dircontents && $currentline == 0)
             or (/\cY/ && $baseindex == 0);
    my $displacement = -(/^\cY$/)
                       +(/^\cE$/);
    $baseindex   += $displacement;
    $currentline -= $displacement if $currentline-$displacement >= 0
                                and $currentline-$displacement <= $screenheight;
#    &validate_position;
#    $scr->at(0,0)->puts("$currentline,$baseindex");
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
                       -($currentline  +$baseindex)              *(/^home$/)
                       +($#dircontents -$currentline -$baseindex)*(/^end$/ );
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
    my $refresh    = $R_KEY;
    my $temp_state = $swap_state;
    if ($swap_state and !$swap_persistent) { # swap back if ok_to_remove_marks
        if (&ok_to_remove_marks) {
            $currentdir     =   $swap_state->{path};
            @dircontents    = @{$swap_state->{contents}};
            $position_at    =   $swap_state->{position};
            %disk           = %{$swap_state->{disk}};
            %selected_nr_of = %{$swap_state->{selected}};
            %total_nr_of    = %{$swap_state->{totals}};
            $multiple_mode  =   $swap_state->{multiple_mode};
            $sort_mode      =   $swap_state->{sort_mode};
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
                        sort_mode     =>   $sort_mode
                       };
        $currentdir     =   $temp_state->{path};
        @dircontents    = @{$temp_state->{contents}};
        $position_at    =   $temp_state->{position};
        %disk           = %{$temp_state->{disk}};
        %selected_nr_of = %{$temp_state->{selected}};
        %total_nr_of    = %{$temp_state->{totals}};
        $multiple_mode  =   $temp_state->{multiple_mode};
        $sort_mode      =   $temp_state->{sort_mode};
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
                        sort_mode     =>   $sort_mode
                       };
        $swap_mode     = 1;
        $sort_mode     = $pfmrc{sortmode} || 'n';
        $multiple_mode = 0;
        $scr->at(0,0)->clreol()->bold()->cyan()
            ->puts('Directory Pathname: ')->normal()->cooked();
        $currentdir = &readintohist(\@path_history);
        $scr->raw();
        $position_at = '.';
        $refresh = $R_CHDIR;
    }
    if ( !chdir $currentdir ) {
        &display_error("$currentdir: $!");
        $currentdir = getcwd();
        $refresh = $R_HEADER;
    }
    &init_title($swap_mode,$uid_mode);
    return $refresh;
}

sub handleentry {
    local $_ = $_[0];
    my ($tempptr, $nextdir, $success, $direction);
    if ( /^kl|h|\e$/i ) {
        $nextdir   = '..';
        $direction = 'up';
    } else {
        $nextdir   = $currentfile{name};
        $direction = $nextdir eq '..' ? 'up' : 'down';
    }
    return $R_KEY if ($nextdir    eq '.');
    return $R_KEY if ($currentdir eq '/' && $direction eq 'up');
    return $R_KEY if ! &ok_to_remove_marks;
    $success = chdir($nextdir);
    if ($success && $direction =~ /up/ ) {
        $oldcurrentdir = $currentdir;
        $position_at   = &basename($currentdir);
    } elsif ($success && $direction =~ /down/) {
        $oldcurrentdir = $currentdir;
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
#    my ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size);
#    my ($atime,$mtime,$ctime,$blksize,$blocks);
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
    $ptr->{display}  = $entry.$ptr->{target};
    $ptr->{too_long} = length($ptr->{display})>$maxfilenamelength ? '+' : ' ';
    $total_nr_of{ $ptr->{type} }++; # this is wrong! e.g. after cOmmand
    if ($ptr->{type} =~ /[bc]/) {
        $ptr->{size}=sprintf("%d",$rdev/256).$MAJORMINORSEPARATOR.($rdev%256);
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
        for (0..$#dircontents) {
            if ($position_at eq $dircontents[$_]{name}) {
                $currentline = $_ - $baseindex;
                last ANYENTRY;
            }
        }
        $baseindex = 0;
    }
    $position_at = '';
    return &validate_position; # refresh flag
}

sub resizehandler {
    $wasresized = 0;
    &handlefit;
    return &validate_position;
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
#                                 get filesystem info;
# L_DIRCONTENTS (R_DIRCONTENTS):  read directory contents;
# DISPLAY       (R_SCREEN):       show title, footer and stats;
# L_DIRLISTING  (R_DIRLISTING):   display directory contents;
# STRIDE        (R_STRIDE):       wait for key;
# KEY           ():               call sub handling key command;
#                                 jump to redo point (using R_*);
#               (R_CHDIR):
#               (R_QUITTING):
# }
#
# actually, jumps have been implemented using do..until loops.
# redo points are jumped to according to the result of the sub that handles
# the key command. these subs are supposed to return a value which reports
# the "severity" of the result. the higher the value, the more redrawing
# should be done on-screen, i.e. the more loops should be exited from.
# the following are valid return values, in increasing order of severity:
#
# $R_KEY         == 0;
# $R_HEADER      == 1; # just call init_header()
# $R_STRIDE      == 2;
# $R_DIRLISTING  == 3;
# $R_SCREEN      == 4;
# $R_CLEAR       == 5; # like R_SCREEN, but clrscr() first
# $R_DIRCONTENTS == 6;
# $R_CHDIR       == 7;
# $R_QUITTING    == 255;

sub browse {
    my ($key, $result);
    # collect info
    $currentdir = getcwd();
    %disk       = &get_filesystem_info;
    $0          = 'pfm [on ' . ( $disk{device} eq 'none'
                               ? $disk{mountpoint} : $disk{device} ) . ']';
    L_DIRCONTENTS: do {
        %total_nr_of    = ( d=>0, l=>0, '-'=>0, c=>0, b=>0, 's'=>0, p=>0, D=>0);
        %selected_nr_of = ( d=>0, l=>0, '-'=>0, c=>0, b=>0, 's'=>0, p=>0, D=>0,
                            bytes=>0 );
        @dircontents    = sort as_requested (&getdircontents($currentdir));
        DISPLAY: do {
            &redisplayscreen;
            if ($position_at ne '') { &position_cursor }
            &recalc_ptr unless defined $dircontents[$currentline+$baseindex];
            L_DIRLISTING: do {
                &printdircontents(@dircontents);
#                $scr->flush_input();
                STRIDE: do {
                    %currentfile = %{$dircontents[$currentline+$baseindex]};
                    &highlightline($HIGHLIGHT_ON);
                    until ($scr->key_pressed(1)) {
                        if ($wasresized) { &resizehandler }
                        &date_info($DATELINE, $screenwidth-$DATECOL);
                        $scr->at($currentline+$BASELINE, 0);
                    }
                    $key = $scr->getch();
                    &highlightline($HIGHLIGHT_OFF);
                    $result = $R_KEY;
                    KEY: for ($key) {
                        /^(?:kr|kl|[hl\e])$/i
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
                        /^[s\r]$/  and $result = &handleshowenter($_), last KEY;
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
                        /^[\/f]$/i and $result = &handlefind($_),      last KEY;
                        /^k1$/     and $result = &handlehelp,          last KEY;
                        /^k2$/     and $result = &handlecdold,         last KEY;
                        /^k9$/     and $result = &handlecolumns,       last KEY;
                        /^k4$/     and $result = &handlecolor,         last KEY;
                        /^\@$/     and $result = &handleperlcommand,   last KEY;
                        /^u$/i     and $result = &handlechown,         last KEY;
                    } # end KEY
                    if ($result == $R_HEADER) { &init_header($multiple_mode) }
                } until ($result > $R_STRIDE);
                # end STRIDE
            } until ($result > $R_DIRLISTING);
            # end L_DIRLISTING
            if ($result == $R_CLEAR) { $scr->clrscr }
        } until ($result > $R_CLEAR);
        # end DISPLAY
    } until ($result > $R_DIRCONTENTS);
    # end L_DIRCONTENTS
    return $result == $R_QUITTING;
} # end sub browse

##########################################################################
# void main (void)

&globalinit;
until (&browse) { $multiple_mode = 0 };
&goodbye;
exit 0;

__DATA__
##########################################################################
# Configuration file for Personal File Manager
# Version x

# every option line in this file should have the form:
# [whitespace] option [whitespace]:[whitespace] value
# (whitespace is optional)
# in other words: /^\s*([^:\s]+)\s*:\s*(.*)$/
# lines may be broken by ending them in \

# some options can be set using environment variables.
# your environment settings override the options in this file.

##########################################################################
# General

# define your pager. you can also use $PAGER for this
#pager:less
# your editor. you can also use $EDITOR
editor:vi
# your system's print command. Specify if the default 'lpr' does not work.
#printcmd:lp -d$ENV{PRINTER}

# the erase character for your terminal
#erase:^H
# the keymap to use in readline (vi,emacs); default emacs
#keymap:vi

# whether multiple file mode should be exited after executing a multiple command
autoexitmultiple:1
# use very visible cursor (block cursor on 'linux' type terminal)
cursorveryvisible:1
# write history files automatically upon exit
autowritehistory:0
# time to display copyright message at start (in seconds, fractions allowed)
copyrightdelay:0.2
# whether you want to have the screen cleared when pfm exits (0 or 1)
clsonexit:0
# have pfm ask for confirmation when you press 'q'uit? (always,never,marked)
# 'marked' = ask only if there are any marked files in the current directory
confirmquit:always
# initial sort mode (see F6 command) (nNmMeEfFsSiItTdDaA) (n is default)
sortmode:n
# initial title bar mode (F9 command) (0=mtime, 1=uid, 2=atime) (0 is default)
uidmode:0
# format for time: touch MMDDhhmm[[CC]YY][.ss] or pfm [[CC]YY]MMDDhhmm[.ss]
timeformat:pfm
# show whether mandatory locking is enabled (e.g. -rw-r-lr-- ) (yes,no,sun)
showlock:sun
# F7 key swap path method is persistent? (0,1) (0 is default)
#persistentswap:0

##########################################################################
# Colors

# set 'usecolor' to 0 if you want no color at all. if you set this to 1,
# you will get colored title bars (if your terminal supports it).
# set this to 2 to force pfm to try and use color on any terminal.
# your *files* will only be colored if you also define 'dircolors' below
usecolor:2

# 'dircolors' defines the colors that will be used for your files.
# for your files to become colored, you must set 'usecolor' to 1.
# see also the manpages for ls(1) and dircolors(1L) (on Linux systems).
# if you don't want to set this, you can also use $LS_COLORS or $LS_COLOURS

#-attribute codes:
# 00=none 01=bold 04=underscore 05=blink 07=reverse 08=concealed
#-text color codes:
# 30=black 31=red 32=green 33=yellow 34=blue 35=magenta 36=cyan 37=white
#-background color codes:
# 40=black 41=red 42=green 43=yellow 44=blue 45=magenta 46=cyan 47=white
#-file types:
# no=normal fi=file di=directory ln=symlink pi=fifo so=socket bd=block special
# cd=character special or=orphan link mi=missing link ex=executable
# *.<ext> defines extension colors

# you may specify the escape as a real escape, as \e or as ^[ (caret, bracket)

dircolors:no=00:fi=00:di=01;34:ln=01;36:pi=00;40;33:so=01;35:bd=40;33;01:\
cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:ex=00;32:lc=^[[:rc=m:\
*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:*.pas=32:\
*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:\
*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.rpm=31:*.pm=00;36:*.pl=00;36:\
*.jpg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:\
*.mpg=01;37:*.avi=01;37:*.gl=01;37:*.dl=01;37:*.htm=01;33:*.html=01;33

# use this if you want no colors for your files, but only for the title bars
#dircolors:-

# colors for header, title, footer; title and footer are always in reverse!
# these are commented out because they are the defaults
#headercolor:37;44
#multicolor:36;47
#titlecolor:36;47;07
#swapcolor:36;40;07
#footercolor:34;47;07

##########################################################################
# Your commands

B:xv -root +noresetroot +smooth -maxpect -quit "\2"
C:tar cvf - "\2" | gzip > "\2".tar.gz
D:uudecode "\2"
E:unarj l "\2" | more
F:file "\2"
G:gvim "\2"
I:rpm -qp -i "\2"
J:mpg123 "\2" &
L:mv "\2" `echo "\2" | tr A-Z a-z`
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

__END__

##########################################################################
# Pod Documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [>I<directory>C<]>

=head1 DESCRIPTION

C<pfm> is a terminal-based file manager. This version was based on PFM.COM
2.32, originally written for MS-DOS by Paul R. Culley and Henk de Heer.

All C<pfm> commands are one- or two-letter commands (case-insensitive).
C<pfm> can operate in single-file mode or multiple-file mode.
In single-file mode, the command corresponding to the keypress will be
executed on the file next to the cursor only. In multiple-file mode, the
command will apply to all files which the user has previously marked.
See FUNCTION KEYS below for the relevant commands.

Note that throughout this manual page, I<file> can mean any type
of file, not just plain regular files. These will be referred to as
I<regular files>.

=head1 OPTIONS

=over

You may specify a starting directory on the command line when invoking
C<pfm>. There are no command line options. Configuration is read from a
file, F<$HOME/.pfm/.pfmrc> , which is created automatically the first
time you start C<pfm>. The file is supposed to be self-explanatory.
See also MORE COMMANDS below.

=back

=head1 NAVIGATION

=over

Navigation through directories is done using the arrow keys, the
C<vi>(1) cursor keys (B<hjkl>), B<->, B<+>, B<PgUp>, B<PgDn>, B<home>,
B<end>, B<CTRL-F>, B<CTRL-B>, B<CTRL-U>, B<CTRL-D>, B<CTRL-Y> and
B<CTRL-E>. Pressing B<ESC> will take you one directory level up (but:
see BUGS below). Pressing B<ENTER> when the cursor is on a directory
will take you into the directory. Pressing B<SPACE> will both mark the
current file and advance the cursor.

=back

=head1 COMMANDS

=over

=item B<@>

Allows the user to enter a perl command to be executed in the context
of C<pfm>. Primarily used for debugging.

=item B<Attrib>

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
directory, show a different directory, or write the history files to
disk. See MORE COMMANDS below. Pressing B<ESC> will take you back to
the main menu.

=item B<cOmmand>

Allows execution of a shell command on the current files. Entering an
empty line will spawn your default login shell until you C<exit> from it.
After the command completes, C<pfm> will resume.  You may abbreviate
the current filename as B<\2>, the current filename without extension
as B<\1>, the current directory path as B<\3>, the mount point of the
current filesystem as B<\4> and the swap directory path (see B<F7>
command) as B<\5>. To enter a backslash, use B<\\>.

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

Change the name of the file to the name specified. A different pathname
and filename in the same filesystem is allowed. In multiple-file mode,
the new name I<must> be a directoryname or a name containing a B<\1>
or B<\2> escape (see cB<O>mmand above).

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
target of the symbolic link.

=item B<eXclude>

Allows you to erase marks on a group of files which meet a certain
criterion. See B<I>nclude for details.

=item B<Your command>

Like cB<O>mmand (see above), except that it uses commands that have
been preconfigured in F<$HOME/.pfm/.pfmrc> by a I<letter>B<:>I<command>
line. Commands may use B<\1>-B<\5> escapes just as in cB<O>mmand, e.g.

 C:tar cvf - \2 | gzip > \2.tar.gz
 W:what \2

=back

=head1 MORE COMMANDS

=over

=item Config PFM

This option will open the F<$HOME/.pfm/.pfmrc> configuration file with
your preferred editor. The file is re-read by C<pfm> after you exit
your editor.

=item Edit new file

You will be prompted for the new filename, then your editor will
be spawned.

=item Make new directory

Specify a new directory name and C<pfm> will create it for you.
Furthermore, if you don't have any files marked, your current
directory will be set to the newly created directory.

=item Show new directory

You will have to enter the new directory you want to view. Just pressing
B<ENTER> will take you to your home directory. Be aware that this option
is different from B<F7> because this will not change your current swap
directory status.

=item Write history

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

=item B<SPACE>

Toggles the include flag (mark) on an individual file and advances the
cursor to the next directory entry.

=item B<ENTER>

Displays the contents of the current file or directory on the screen.
If the current file is executable, the executable will be invoked.

=item B<ESC>

Shows the parent directory of the current one (go up in the directory
tree).

=back

=head1 WORKING DIRECTORY INHERITANCE

=over

Upon exit, C<pfm> will save its current working directory in a file
F<$HOME/.pfm/cwd> . In order to have this directory "inherited" by the
calling process (shell), you may call C<pfm> using a function like the
following (example for C<bash>(1), add it to your F<.profile>):

 pfm () {
     /usr/local/bin/pfm $*
     if [ -n ~/.pfm/cwd ]; then
         cd "`cat ~/.pfm/cwd`" # double quotes for names with spaces
         rm -f ~/.pfm/cwd
     fi
 }

=back

=head1 ENVIRONMENT

=over

=item B<EDITOR>

The editor to be used for the B<E>dit command.

=item B<HOME>

The directory where the B<M>ore - B<S>how new dir command will take you
if you don't specify a new directory.

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

The directory F<$HOME/.pfm/> and files therein. Also, an input history
is kept in this directory.

=head1 BUGS and WARNINGS

When typed by itself, the B<ESC> key needs to be pressed twice. This is
due to the lack of a proper timeout in C<Term::Screen.pm>.

In order to allow spaces in filenames, several commands assume they can
safely surround filenames with double quotes. This prevents the correct
processing of filenames containing double quotes.

Sometimes when key repeat sets in, not all keypress events have been
processed, although they have been registered. This can be dangerous
when deleting files.

The author once almost pressed ENTER when logged in as root and with
the cursor next to F</sbin/reboot> . You have been warned.

=head1 AUTHOR

RenE<eacute> Uittenbogaard (ruittenbogaard@profuse.nl)

=head1 SEE ALSO

The documentation on PFM.COM . The mentioned manual pages for
C<chmod>(1), C<less>(1), C<lpr>(1), C<touch>(1). The manual pages for
C<Term::ScreenColor>(3) and C<Term::ReadLine::Gnu>(3).

=head1 VERSION

This manual pertains to C<pfm> version 1.44 .

=cut

# vi: set tabstop=4 shiftwidth=4 expandtab list:
