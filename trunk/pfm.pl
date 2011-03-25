#!/usr/local/bin/perl
#
##########################################################################
# @(#) pfm.pl 30-07-1999 v0.99.12
#
# Author:      Rene Uittenbogaard
# Usage:       pfm.pl [directory]
# Description: Personal File Manager for Unix/Linux
# Version:     v0.99.12
# Date:        30-07-1999
# 
# TO-DO: multiple rename
#        change ownership testen
#        tidy up multiple commands
#        titlebar colors configurable
#        validate_position in SIG{WINCH}
#        key response (flush_input)
# terminal:
#        intelligent restat (changes in current dir?)
#        apply color correctly when $screenwidth>80
#        display '+' correctly when $screenwidth>80
#        make use of Term::Complete?
#        command history
# documentation:
#        man page
#        comments in english
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
# declarations and initialization

require Term::ScreenColor;
use strict 'refs','subs';

my $VERSION='0.99.12';
my $configfilename=".pfmrc";
my $majorminorseparator=',';
my $maxfilenamelength=20;
my $errordelay=1;     # seconds
my $slowentries=300;
my $baseline=3;
my $screenheight=20; # inner height
my $screenwidth=80; # terminal width
my $userline=21;
my $dateline=22;
my $datecol=14;
my $position_at='.';
my @sortmodes=( n =>'Name',        N =>' reverse',
               'm'=>' ignorecase', M =>' rev+ignorec',
                e =>'Extension',   E =>' reverse',
                f =>' ignorecase', F =>' rev+ignorec',
                d =>'Date/Time',   D =>' reverse',
               's'=>'Size',        S =>' reverse',
                t =>'Type',        T =>' reverse',
                i =>'Inode',       I =>' reverse'       );
my %timehints = ( pfm   => '[[CC]YY]MMDDhhmm[.ss]',
                  touch => 'MMDDhhmm[[CC]YY][.ss]' );
my (%user,%group,$sort_mode,$multiple_mode,$swap_mode,$uid_mode,
    %currentfile,$currentline,$baseindex,
    $editor,$pager,$printcmd,$clsonexit,$cwdinheritance,$confirmquit,
    $timeformat,%dircolors,%pfmrc,$scr,$wasresized);

sub init_uids {
    my (%user,$name,$pwd,$uid);
    while (($name,$pwd,$uid)=getpwent) {
        $user{$uid}=$name
    }
    return \%user;
}

sub init_gids {
    my (%group,$name,$pwd,$gid);
    while (($name,$pwd,$gid)=getgrent) {
        $group{$gid}=$name
    }
    return \%group;
}

sub read_pfmrc { # $rereadflag - 0=read 1=reread
    $uid_mode=$sort_mode=$editor=$pager=$clsonexit
             =$cwdinheritance=$confirmquit='';
    %dircolors=%pfmrc=();
    local $_;
    if (open PFMRC,"$ENV{HOME}/$configfilename") {
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
        $scr->colorizable(0);
    } elsif (defined($pfmrc{usecolor}) && ($pfmrc{usecolor}==2)) {
        $scr->colorizable(1);
    }
    &copyright($pfmrc{copyrightdelay}) unless ($_[0]);
    $clsonexit     = $pfmrc{clsonexit};
    $confirmquit   = $pfmrc{confirmquit};
    $cwdinheritance= $pfmrc{cwdinheritance};
    $printcmd      = $pfmrc{printcmd}   || 'lpr';
    $timeformat    = $pfmrc{timeformat} || 'pfm';
    $sort_mode     = $pfmrc{sortmode}   || 'n';
    $uid_mode      = $pfmrc{uidmode};
    $editor        = $pfmrc{editor}     || $ENV{EDITOR} || 'vi';
    $pager         = $pfmrc{pager}      || $ENV{PAGER}  ||
                      ($^O =~ /linux/i ? 'less' : 'more');
#    system "stty erase $erase" if defined($erase);
    foreach (keys %pfmrc) {
        $pfmrc{$_} =~ s/\^\[|\\e/\e/g; # insert escapes
    }
    $pfmrc{dircolors} ||= $ENV{LS_COLORS} || $ENV{LS_COLOURS};
    if ($pfmrc{dircolors}) {
        while ($pfmrc{dircolors} =~ /([^:=*]+)=([^:=]+)/g ) {
            $dircolors{$1}=$2;
        }
    }
}

##########################################################################
# some translations

sub mtime2str {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst,$monname,$val);
    ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($_[0]);
    $monname =(qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/)[$mon];
    foreach $val ($mday,$hour,$min,$sec) { if ($val<10) { $val="0$val" } }
    if ($_[1]) {
        $min="$min:$sec";
        $year += 1900;
    } else {
        $year %= 100;
    }
    if ($year<10) { $year="0$year" }
    return "$year $monname $mday $hour:$min";
}

sub mode2str {
    my $strmode;
    my $nummode=shift;
    my $octmode=sprintf("%lo",$nummode);
    my @strmodes=(qw/--- --x -w- -wx r-- r-x rw- rwx/);
    $octmode =~ /(\d\d?)(\d)(\d)(\d)(\d)$/;
    $strmode = substr('^pc^d^b^-^l^s^=D=^=^d',oct($1),1)
               .$strmodes[$3].$strmodes[$4].$strmodes[$5];
               # first  d for Linux, OSF1, Solaris
               # second d for AIX
               # D is Solaris Door
    if ($2 & 4) { substr($strmode,3,1) =~ tr/-x/Ss/ }
    if ($2 & 2) { substr($strmode,6,1) =~ tr/-x/Ss/ }
    if ($2 & 1) { substr($strmode,9,1) =~ tr/-x/Tt/ }
    return $strmode;
}

sub fit2limit {
    my $neatletter='';
    my $neatsize=$_[0];
    my $limit=9999999;
    while ( $neatsize > $limit ) {
        $neatsize = int($neatsize/1024);
        $neatletter =~ tr/KMGT/MGTP/ || do { $neatletter = 'K' };
        $limit=999999;
    }
    return $neatsize.$neatletter;
}

sub expand_escapes {
    my %thisfile = %{$_[1]};
    my $namenoext =
        $thisfile{name} =~ /^(.*)\.(\w+)$/ ? $1 : $thisfile{name};
    $_[0] =~ s/\e1/$namenoext/g;
    $_[0] =~ s/\e2/$thisfile{name}/g;
    $_[0] =~ s!\e3!$currentdir/!g;
    $_[0] =~ s!\e5!$swap_mode->{path}/!g if $swap_mode;
}

sub basename {
    $_[0] =~ m!/([^/]*)$!;
    return $1;
}

sub toggle {
    $_[0]=!$_[0];
}

sub exclude { # $entry,$oldmark
    my ($entry,$oldmark) = @_;
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
    local $_;
    foreach (split /;/,$_[0]) { $scr->color($_) }
}

sub decidecolor {
    my %file=@_;
    $file{type} eq 'd' and &digestcolor($dircolors{di}), return;
    $file{type} eq 'l' and &digestcolor($dircolors{ln}), return;
    $file{type} eq 'b' and &digestcolor($dircolors{bd}), return;
    $file{type} eq 'c' and &digestcolor($dircolors{cd}), return;
    $file{type} eq 'p' and &digestcolor($dircolors{pi}), return;
    $file{type} eq 's' and &digestcolor($dircolors{so}), return;
    $file{type} eq 'D' and &digestcolor($dircolors{'do'}), return;
    $file{mode} =~ /[xst]/ and &digestcolor($dircolors{ex}), return;
    $file{name} =~/(\.\w+)$/ and &digestcolor($dircolors{$1}), return;
}

sub applycolor { 
    if ($scr->colorizable()) {
        my ($line,$length,%file)=(shift,shift,@_);
        $length= $length ? 255 : 20;
        &decidecolor(%file);
        $scr->at($line,2)->puts(substr($file{name},0,$length))->normal();
    }
}

##########################################################################
# small printing routines

sub pathline {
    $^A = "";
    formline('@'.'<'x($screenwidth-$datecol-2).' [@<<<<<<<<<<<]',@_);
    return $^A;
}

sub uidline {
    $^A = "";
    formline('@ @'.'<'x($screenwidth-$datecol-47)
            .'@@>>>>>>  @<<<<<<< @<<<<<<<@###  @<<<<<<<<<',@_);
    return $^A;
}

sub tdline {
    $^A = "";
    formline('@ @'.'<'x($screenwidth-$datecol-47)
            .'@@>>>>>>  @<<<<<<<<<<<<<<@###### @<<<<<<<<<'
            ,@_[0,1,2,3],&mtime2str($_[4],0),@_[5,6]);
    return $^A;
}

sub fileline {
    my %specs=@_;
    my $neatsize = &fit2limit($specs{size});
    if ($uid_mode) {
        return &uidline( @specs{qw/selected display too_long/},$neatsize,
                         @specs{qw/uid gid nlink mode/}      );
    } else {
        return  &tdline( @specs{qw/selected display too_long/},$neatsize,
                         @specs{qw/mtime inode mode/}        );
    }
}

sub highlightline { # true/false
    $scr->at($currentline+$baseline,0);
    $scr->bold() if $_[0];
    $scr->puts(&fileline(%currentfile));
    &applycolor($currentline+$baseline,0,%currentfile);
    $scr->normal()->at($currentline+$baseline,0);
}

sub markcurrentline { # letter
    $scr->at($currentline+$baseline,0)->puts($_[0]);
}

sub pressanykey {
    $scr->cyan();
    print "\n*** Hit any key to continue ***";
    $scr->normal()->raw()->getch();
}

sub display_error { 
#    $scr->at(0,0)->clreol();
    $scr->cyan()->bold()->puts($_[0])->normal();
    return $scr->key_pressed($errordelay); # return value not actually used
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
    chop ($wildfilename=<STDIN>);
    $scr->raw();      # init_header is done in handleinclude
    eval "/$wildfilename/";
    if ($@) {
        &display_error($@);
        $scr->key_pressed(2*$errordelay); # triple reporting time
        $wildfilename = '^$';             # clear illegal regexp
    }
    return $wildfilename;
}

sub clearcolumn {
    local $_;
    my $spaces=' 'x$datecol;
    foreach ($baseline..$baseline+$screenheight) {
        $scr->at($_,$screenwidth-$datecol)->puts($spaces);
    }
}

##########################################################################
# headers, footers

sub print_with_shortcuts {
    my ($printme,$pattern)=@_;
    $scr->on_blue()->puts($printme)->bold();
    while ($printme =~ /$pattern/g) { 
        $pos=pos($printme)-1;
        $scr->at(0,$pos)->puts(substr($printme,$pos,1));
    }
    $scr->normal();
}

sub init_frame { # multiple_mode, swap_mode, uid_mode
   &init_header($_[0]);
   &init_title(@_[1,2]);
   &init_footer;
}

sub init_header { # "multiple"mode
    my $mode=shift;
    my @header=split(/\n/,<<_eoFirst_);
Attrib Time Copy Delete Edit Print Rename Show Your cOmmands Quit View Uid More 
Multiple Include eXclude Attribute Time Copy Delete Print Rename Your cOmmands  
Include? Every, Oldmarks, User or Files only:                                   
Config PFM Edit new file Make new dir Show new dir ESC to main menu             
Sort by: Name, Extension, Size, Date, Type, Inode (ignorecase, reverse):        
_eoFirst_
    $scr->at(0,0);
    &print_with_shortcuts($header[$mode].' 'x($screenwidth-80),
                          "[A-Z](?!FM|M E| Ed)");
    if ($mode == 1) { 
        $scr->reverse()->bold()->cyan()->on_white()
            ->at(0,0)->puts("Multiple")->normal();
    }
}

sub init_title { # swap_mode, uid_mode
    my ($swapmode,$uidmode)=@_;
    my @title=split(/\n/,<<_eoKop_);
size  date      time   inode attrib          disk info
size  userid   groupid lnks  attrib          disk info
size  date      time   inode attrib     your commands 
size  userid   groupid lnks  attrib     your commands 
size  date      time   inode attrib     sort mode     
size  userid   groupid lnks  attrib     sort mode     
_eoKop_
    $swapmode ? $scr->on_black()
              : $scr->on_white()->bold();
    $scr->reverse()->cyan()->at(2,0)
        ->puts('  filename.ext'.' 'x($screenwidth-$datecol-54).$title[$uidmode])
        ->normal();
}

sub init_footer {
    my $footer;
    chop($footer=<<_eoFunction_);
F1-Help F3-Fit F4-Color F5-Reread F6-Sort F7-Swap F8-Include F9-Uids F10-Multi  
_eoFunction_
    $scr->reverse()->bold()->blue()->on_white()->at($baseline+$screenheight+1,0)
        ->puts($footer.' 'x($screenwidth-80))->normal();
}

sub copyright {
    $scr->cyan()->puts("PFM $VERSION for Unix computers and compatibles.")
        ->at(1,0)->puts("Copyright (c) 1999 Rene Uittenbogaard")
        ->at(2,0)->puts("This software comes with no warranty: see the file "
                       ."COPYING for details.")->normal();
    return $scr->key_pressed($_[0]);
}

sub goodbye {
    if ($clsonexit) {
        $scr->clrscr();
    } else {
        $scr->at(0,0)->puts(<<_eoGoodbye_);
                    Goodbye from your Personal File Manager!                    
_eoGoodbye_
        $scr->normal()->at($screenheight+$baseline+1,0)->clreol();
    }
    if ($cwdinheritance) {
        open CWDFILE,">$cwdinheritance"
            or warn "Cannot create $cwdinheritance: $!";
        print CWDFILE `pwd`;
        close CWDFILE;
    }
    exit 0;
}

sub credits {
    $scr->clrscr()->cooked();
    print <<"_eoCredits_";


             PFM for Unix computers and compatibles.  Version $VERSION
             Original idea/design: Paul R. Culley and Henk de Heer
                Author and Copyright (c) 1999 Rene Uittenbogaard


       PFM is distributed under the GNU General Public License version 2.
                    PFM is distributed without any warranty,
             even without the implied warranties of merchantability 
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.


      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to update this product.


     For questions/remarks about PFM, or just to tell me you are using it,
                   send email to: ruittenbogaard\@profuse.nl


                                                          any key to exit to PFM
_eoCredits_
    $scr->raw()->getch();
    $scr->clrscr();
}

##########################################################################
# system information

sub user_info {
    $^A = "";
    formline('@>>>>>>>',$user{$>});
    $scr->at($userline,$screenwidth-$datecol+6)->puts($^A);
}

sub infoline { # number, description
    $^A = "";
    formline('@>>>>>> @<<<<<',@_);
    return $^A;
}

sub disk_info { # %disk{ total, used, avail }
    local $_;
    my @desc=('K tot','K usd','K avl');
    my @values=@disk{qw/total used avail/};
    my $startline=4;
    $scr->at($startline-1,$screenwidth-$datecol+4)->puts('Disk space');
    foreach (0..2) {
        while ( $values[$_] > 99999 ) {
                $values[$_] /= 1024;
                $desc[$_] =~ tr/KMGT/MGTP/;
        }
        $scr->at($startline+$_,$screenwidth-$datecol+1)
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
    my $startline=9;
    $scr->at($startline-1,$screenwidth-$datecol+5)->puts('Directory');
    foreach (0..3) {
        $scr->at($startline+$_,$screenwidth-$datecol+1)
            ->puts(&infoline($values[$_],$desc[$_]));
    }
}

sub mark_info {
    my @desc=qw/bytes files dirs symln spec/;
    my @values=@selected_nr_of{'bytes','-','d','l'};
    $values[4] = $selected_nr_of{'c'} + $selected_nr_of{'b'}
               + $selected_nr_of{'p'} + $selected_nr_of{'s'}
               + $selected_nr_of{'D'};
    my $startline=15;
    my $total=0;
    $values[2]=&fit2limit($values[2]);
    $scr->at($startline-1,$screenwidth-$datecol+2)->puts('Marked files');
    foreach (0..4) {
        $scr->at($startline+$_,$screenwidth-$datecol+1)
            ->puts(&infoline($values[$_],$desc[$_]));
        $total+=$values[$_];
    }
    return $total;
}

sub date_info {
    my ($line,$col)=@_;
    my ($datetime,$date,$time);
    $datetime=&mtime2str(time,1);
    ($date,$time) = ($datetime =~ /(.*)\s+(.*)/);
    if ($scr->getrows() > 24) {
        $scr->at($line++,$col+3)->puts($date);
        $scr->at($line++,$col+6)->puts($time);
    } else {
        $scr->at($line++,$col+6)->puts($time);
    }
}

##########################################################################
# sorting sub

sub as_requested { 
    my ($exta,$extb);
    SWITCH:
    for ($sort_mode) {
        /n/ and return    $a->{name}  cmp    $b->{name},    last SWITCH;
        /N/ and return    $b->{name}  cmp    $a->{name},    last SWITCH;
        /m/ and return lc($a->{name}) cmp lc($b->{name}),   last SWITCH;
        /M/ and return lc($b->{name}) cmp lc($a->{name}),   last SWITCH;
        /d/ and return    $a->{mtime} <=>    $b->{mtime},   last SWITCH;
        /D/ and return    $b->{mtime} <=>    $a->{mtime},   last SWITCH;
        /s/ and return    $a->{size}  <=>    $b->{size},    last SWITCH;
        /S/ and return    $b->{size}  <=>    $a->{size},    last SWITCH;
        /i/ and return    $a->{inode} <=>    $b->{inode},   last SWITCH;
        /I/ and return    $b->{inode} <=>    $a->{inode},   last SWITCH;
        /t/ and return $a->{type}.$a->{name}
                                     cmp $b->{type}.$b->{name}, last SWITCH;
        /T/ and return $b->{type}.$b->{name}
                                     cmp $a->{type}.$a->{name}, last SWITCH;
        /[ef]/i and do {
             if ($a->{name} =~ /^(.*)(\.\w+)$/) { $exta=$2."\0377".$1 }
                                           else { $exta="\0377".$a->{name} };
             if ($b->{name} =~ /^(.*)(\.\w+)$/) { $extb=$2."\0377".$1 }
                                           else { $extb="\0377".$b->{name} };
             if    (/e/) { return    $exta  cmp    $extb  }
             elsif (/E/) { return    $extb  cmp    $exta  }
             elsif (/f/) { return lc($exta) cmp lc($extb) }
             elsif (/F/) { return lc($extb) cmp lc($exta) }
        };
    }
}

##########################################################################
# user commands

sub handlequit {
    return 1 if $confirmquit =~ /never/i;
    return 1 if ($confirmquit =~ /marked/i and !&mark_info);
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("Are you sure you want to quit [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return $sure =~ /y/i;
}

sub handlefit {
    $scr->resize();
    my $newheight= $scr->getrows();
    my $newwidth = $scr->getcols();
    if ($newheight || $newwidth) {
        $screenheight=$newheight-$baseline-2;
        $screenwidth =$newwidth;
        $scr->clrscr();
        &redisplayscreen;
    }
}

sub handlemore {
    local $_;
    my $do_a_refresh=0;
    my $newname;
    &init_header(3);
    my $key=$scr->at(0,68)->getch();
    for ($key) {
        /^s$/i and do {
            return 0 unless &ok_to_remove_marks;
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('Directory Pathname: ')->normal()
                ->cooked()->at(0,20);
            chop($currentdir=<STDIN>);
            $scr->raw();
            $position_at='.';
            if ( !chdir $currentdir ) {
                &display_error("$currentdir: $!");
                chop($currentdir=`pwd`);
            } else { 
                $do_a_refresh=1;
            }
#            &init_title($swap_mode,$uid_mode);
        };
        /^m$/i and do {
            return 0 unless &ok_to_remove_marks;
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('New Directory Pathname: ')->normal()
                ->cooked()->at(0,24);
            chop($newname = <STDIN>);
            $scr->raw();
            $do_a_refresh=1;
            if ( !mkdir $newname,0777 ) {
                &display_error("$newname: $!");
            } elsif ( !chdir $newname ) {
                &display_error("$newname: $!"); # in case of restrictive umask
            } else { 
                chop($currentdir=`pwd`);
                $do_a_refresh=2;
                $position_at='.';
            }
#            &init_title($swap_mode,$uid_mode);
        };
        /^c$/i and do {
            system "$editor $ENV{HOME}/$configfilename" and &display_error($!);
            &read_pfmrc(1);
            $do_a_refresh=1;
        };
        /^e$/i and do {
            $scr->at(0,0)->clreol()
                ->bold()->cyan()->puts('New name: ')->normal()
                ->cooked()->at(0,10);
            chop($newname=<STDIN>);
            system "$editor $newname" and &display_error($!);
            $scr->raw();
            $do_a_refresh=1;
#            &init_title($swap_mode,$uid_mode);
        }
    }
#    &init_header($multiple_mode);
    return $do_a_refresh;
}

sub handleinclude { # include/exclude flag
    local $_;
    my $result=0;
    my ($wildfilename,$criterion);
    my $exin = $_[0];
    &init_header(2);
    if ($exin =~ /x/i) { $scr->at(0,0)->on_blue()->puts('Ex')->normal(); }
    $exin =~ tr/ix/* /;
    my $key=$scr->at(0,46)->getch();
    PARSEINCLUDE: {
    for ($key) {
        /^e$/i and do {    # include every
            $criterion='$entry->{name} !~ /^\.\.?$/';
            $key="prepared";
            redo PARSEINCLUDE;
        };
        /^f$/i and do {    # include files
            $wildfilename=&promptforwildfilename;
            $criterion='$entry->{name} =~ /$wildfilename/ and $entry->{type} eq "-" ';
            $key="prepared";
            redo PARSEINCLUDE;
        };
        /^u$/i and do { # user only
            $criterion = '$entry->{uid}' . " =~ /$ENV{USER}/";
            $key="prepared";
            redo PARSEINCLUDE;
        };
        /^o$/i and do {   # include oldmarks 
            foreach my $entry (@dircontents) {
                if ($entry->{selected} eq "." && $exin eq " ") {
                    $entry->{selected} = $exin;
                } elsif ($entry->{selected} eq "." && $exin eq "*") {
                    &include($entry);
                }
                $result=1;
            }
        };
        /prepared/ and do { # the criterion has been set
            foreach my $entry (@dircontents) {
                if (eval $criterion) {
                    if ($entry->{selected} eq "*" && $exin eq " ") {
                        &exclude($entry);
                    } elsif ($entry->{selected} eq "." && $exin eq " ") {
                        $entry->{selected} = $exin;
                    } elsif ($entry->{selected} ne "*" && $exin eq "*") {
                        &include($entry);
                    }
                    $result=1;
                }
            }
        };
    } # for
    } # PARSEINCLUDE
    &init_header($multiple_mode);
    return $result;
}

sub handleview {
    &markcurrentline('V');
    $scr->at($currentline+$baseline,2)
        ->bold()->puts($currentfile{display}.' ');
    &applycolor($currentline+$baseline,1,%currentfile);
    $scr->normal()->getch();
}

sub handlesort {
    my ($i,$key);
    my $printline=$baseline;
    my %sortmodes=@sortmodes;
    &init_header(4);
    &init_title($swap_mode,$uid_mode+4);
    &clearcolumn;
    for ($i=0; $i<$#sortmodes; $i+=2) {
        $^A="";
        formline('@ @<<<<<<<<<<<',$sortmodes[$i],$sortmodes{$sortmodes[$i]});
        $scr->at($printline++,$screenwidth-$datecol)->puts($^A);
    }
    $key=$scr->at(0,73)->getch();
    &clearcolumn;
    &init_header($multiple_mode);
    if ($sortmodes{$key}) {
        $sort_mode=$key;
        $position_at=$currentfile{name};
        @dircontents=sort as_requested @dircontents;
        return 1;
    } else {
        return 0;
    }
}

sub handlechown {
    my ($newuid,$loopfile,$do_this,$index);
    my $do_a_refresh = $multiple_mode;
    &markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("New user[:group] : ")->normal(); # what about group?
    $scr->cooked();
    chop ($newuid=<STDIN>);
    $scr->raw();
    $do_this = 'system qq/chown '.$1.' $loopfile->{name}/ '
             . 'and &display_error($!), $do_a_refresh++';
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
    my $do_a_refresh = $multiple_mode;
    &markcurrentline('A') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("Permissions ( [ugoa][-=+][rwxst] or octal ): ")->normal();
    $scr->cooked();
    chop ($newmode=<STDIN>);
    $scr->raw();
    if ($newmode =~ /^\s*(\d+)\s*$/) {
        $do_this =           'chmod '.oct($1).  ',$loopfile->{name} '
                  .'or  &display_error($!), $do_a_refresh++';
    } else {
        $do_this = 'system qq/chmod '.$newmode.' "$loopfile->{name}"/'
                  .'and &display_error($!), $do_a_refresh++';
    }
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
    } else { 
        $loopfile=\%currentfile;
        eval($do_this);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
    }
    return $do_a_refresh;
}

sub handlecommand { # Y or O
    local $_;
    my ($key,$command,$do_this,$printstr,$printline,$loopfile,$index);
    &markcurrentline(uc($_[0])) unless $multiple_mode;
    if ($_[0] =~ /y/i) { # Your
        &clearcolumn;
        &init_title($swap_mode,$uid_mode+2);
        $printline=$baseline;
        foreach (sort keys %pfmrc) {
            if (/^[A-Z]$/ && $printline <= $baseline+$screenheight) { 
                $printstr=$pfmrc{$_};
                $printstr =~ s/\e/^[/g;
                $^A="";
                formline('@ @<<<<<<<<<<<',$_,$printstr);
                $scr->at($printline++,$screenwidth-$datecol)->puts($^A);
            }
        }
        $key=$scr->at(0,0)->clreol()
                 ->puts('Enter one of the highlighted chars at right:')
                 ->at(0,45)->getch();
        &clearcolumn;
        return unless ($command = $pfmrc{uc($key)}); # assignment!
        $scr->cooked();
        $command .= "\n";
    } else { # cOmmand
        $printstr=<<_eoPrompt_;
Enter Unix command (ESC1=name, ESC2=name.ext, ESC3=path, ESC5=swap path):
_eoPrompt_
        $scr->at(0,0)->clreol()->bold()->cyan()->puts($printstr)->normal();
        $scr->at(1,0)->clreol()->cooked();
        $command = <STDIN>;
    }
    $command =~ s/^\n?$/$ENV{'SHELL'}\n/;
    if ($multiple_mode) {
        $scr->clrscr()->at(0,0);
        for $index (0..$#dircontents) {
            $loopfile=$dircontents[$index];
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
    } else {
        $loopfile=\%currentfile;
        &expand_escapes($command,\%currentfile);
        $scr->clrscr()->at(0,0)->puts($command);
        system ($command) and &display_error($!);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
    }
    &pressanykey;
    $scr->clrscr();
    &init_frame($multiple_mode,$swap_mode,$uid_mode);
}

sub handledelete { 
    my ($loopfile,$do_this,$index,$success);
    &markcurrentline('D') unless $multiple_mode;
    $scr->at(0,0)->clreol()->cyan()->bold();
    $scr->puts("Are you sure you want to delete [Y/N]? ")->normal();
    my $sure = $scr->getch();
    return 0 if $sure !~ /y/i;
    $do_this = q"if ($loopfile->{type} eq 'd') {
                    $success=rmdir $loopfile->{name};
                 } else {
                    $success=unlink $loopfile->{name};
                 }
                 if ($success) {
                     $total_nr_of{$loopfile->{type}}--;
                     &exclude($loopfile) if $loopfile->{selected} eq '*';
                     if ($currentline+$baseindex >= $#dircontents) {
                         $currentline--; # note
                     }
                     @dircontents=(
                         $index>0             ? @dircontents[0..$index-1]             : (),
                         $index<$#dircontents ? @dircontents[$index+1..$#dircontents] : ()
                     );

                 } else { # not success
                     &display_error($!);
                 }
                 ";
    # the above line marked 'note' uses the fact that a directory can
    # never be empty, so $currentline must be >2 when this occurs
    # unfortunately, for NTFS filesystems, this is not always correct
    # the subroutine position_cursor corrects this
    if ($multiple_mode) {
        # we must delete in reverse order because of the deletions
        # (we could also have done a 'redo LOOP if $success')
        for $index (reverse(0..$#dircontents)) {
            $loopfile=$dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                eval($do_this);
            }
        }
    } else { 
        $loopfile=\%currentfile;
        $index=$currentline+$baseindex;
        eval($do_this);
    }
    &validate_position;
    return 1; # yes, please do a refresh
}

sub handleprint { 
    my ($loopfile,$do_this,$index);
    &markcurrentline('P') unless $multiple_mode;
    $scr->at(0,0)->clreol();
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile=$dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->at(1,0)->clreol()->puts($loopfile->{name});
                &exclude($loopfile,'.');
                system qq/$printcmd "$loopfile->{name}"/ and &display_error($!);
            }
        }
    } else { 
        system qq/$printcmd "$currentfile{name}"/ and &display_error($!);
    }
    &pressanykey;
    $scr->clrscr();
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
    } else {
        system qq/$pager "$currentfile{name}"/ and &display_error($!);
    }
    $scr->clrscr()->raw();
}

sub handlehelp {
    $scr->clrscr();
    # how unsubtle :-)
    system "man pfm";
}

sub handletime {
    my ($newtime,$loopfile,$do_this,$index,$do_a_refresh);
    $do_a_refresh=$multiple_mode;
    &markcurrentline('T') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("Put date/time $timehints{$timeformat}: ")->normal()->cooked();
    chop($newtime=<STDIN>);
    $scr->raw();
    return if ($newtime eq '');
    # convert date/time to touch format if necessary
    if ($timeformat eq 'pfm') {
        $newtime =~ s/^(\d{0,4})(\d{8})(\..*)?/$2$1$3/;
    }
    $do_this = "system qq/touch -t $newtime \$loopfile->{name}/ "
              .'and &display_error($!), $do_a_refresh++';
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
    } else { 
        $loopfile=\%currentfile;
        eval($do_this);
        $dircontents[$currentline+$baseindex] =
            &stat_entry($currentfile{name},$currentfile{selected});
    }
#    &init_frame($multiple_mode,$swap_mode,$uid_mode);
    return $do_a_refresh;
}

sub handleedit {
    my ($loopfile,$index);
    $scr->clrscr()->at(0,0)->cooked();
    if ($multiple_mode) {
        for $index (0..$#dircontents) {
            $loopfile=$dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                $scr->puts($loopfile->{name});
                &exclude($loopfile,'.');
                system qq/$editor "$loopfile->{name}"/ and &display_error($!);
            }
        }
    } else {
        system qq/$editor "$currentfile{name}"/ and &display_error($!);
    }
    $scr->clrscr()->raw();
}

sub handlerename {
    my $newname;
    &markcurrentline('R');
    $scr->at(0,0)->clreol()->bold()->cyan();
    $scr->puts("New name: ")->normal()->cooked();
    chop($newname=<STDIN>);
    &expand_escapes($newname,\%currentfile);
    $scr->raw();
    return if ($newname eq '');
    system(qq/mv "$currentfile{name}" "$newname"/) and &display_error($!);
}

sub handlecopy {
    my ($loopfile,$index,$newname,$command,$do_this);
    my $do_a_refresh=0;
    &markcurrentline('C') unless $multiple_mode;
    $scr->at(0,0)->clreol()->bold()->cyan()
        ->puts("Destination: ")->normal()->cooked();
    chop($newname=<STDIN>);
    $scr->raw();
    return 0 if ($newname eq '');
    if ($multiple_mode and $newname !~ /\e/ and !-d($newname)) {
        $scr->at(0,0)->cyan()->bold()->puts("Cannot do multifile operation"
            ." while destination is single file.")->normal()->getch();
        return 0; # don't refresh screen
    }
    $command = 'system qq{cp $loopfile->{name}'." $newname}";
    if ($multiple_mode) {
        $scr->at(1,0)->clreol();
        for $index (0..$#dircontents) {
            $loopfile=$dircontents[$index];
            if ($loopfile->{selected} eq '*') {
                &exclude($loopfile,'.');
                $do_this = $command;
                &expand_escapes($do_this,$loopfile);
                $scr->at(1,0)->puts($loopfile->{name});
                eval ($do_this) and &display_error($!);
                $do_a_refresh++;
            }
        }
    } else {
        $loopfile=\%currentfile;
        &expand_escapes($command,$loopfile);
        eval ($command) and &display_error($!);
    }
    return $do_a_refresh;
}

sub handleselect {
    my $file = $dircontents[$currentline+$baseindex];
    my $was_selected = $file->{selected} =~ /\*/;
    $file->{selected} = substr('* ',$was_selected,1);
    if ($was_selected) {
        $selected_nr_of{$file->{type}}--;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} -= $file->{size};
    } else {
        $selected_nr_of{$file->{type}}++;
        $file->{type} =~ /-/ and $selected_nr_of{bytes} += $file->{size};
    }
    %currentfile=%$file;
    &highlightline(0);
    &mark_info(%selected_nr_of);
}

sub validate_position {
    my $redraw=0;
    if ( $currentline < 0 ) {
        $baseindex += $currentline;
        $baseindex < 0 and $baseindex=0;
        $currentline = 0;
        $redraw=1;
    }
    if ( $currentline > $screenheight ) { 
        $baseindex += $currentline-$screenheight;
        $currentline = $screenheight;
        $redraw=1;
    }
    if ( $currentline+$baseindex > $#dircontents) {
        $currentline=$screenheight;
        $baseindex  = $#dircontents-$screenheight;
        $baseindex   <0             and $baseindex=0;
        $currentline >$#dircontents and $currentline=$#dircontents;
        $redraw=1;
    }
    return $redraw;
}

sub handlemove {
    local $_=$_[0];
    my $displacement = -10*(/^-$/)  -(/^ku|k$/   )
                       +10*(/^\+$/) +(/^kd|[j ]$/)
                       +$screenheight*(/\cF|pgdn/) +$screenheight*(/\cD/)/2
                       -$screenheight*(/\cB|pgup/) -$screenheight*(/\cU/)/2
                       -($currentline +$baseindex)  *(/^home$/)
                       +($#dircontents-$currentline)*(/^end$/ );
    $currentline += $displacement;
    return &validate_position;
}

sub handleenter {
    $scr->cooked()->clrscr();
    system "./$currentfile{name}" and &display_error($!);
    &pressanykey;
    $scr->clrscr();
}

sub handleswap {
    my $refresh=0;
    if ($swap_mode) {
        if (&ok_to_remove_marks) {
            $currentdir    =   $swap_mode->{path};
            @dircontents   = @{$swap_mode->{contents}};
            $position_at   =   $swap_mode->{position};
            %disk          = %{$swap_mode->{disk}};
            %selected_nr_of= %{$swap_mode->{selected}};
            %total_nr_of   = %{$swap_mode->{totals}};
            $swap_mode=0;
            $refresh=1;
        } else {
            $refresh=0;
        }
    } else {
        $swap_mode={ path     =>   $currentdir,
                     contents => [ @dircontents ],
                     position =>   $currentfile{name},
                     disk     => { %disk },
                     selected => { %selected_nr_of },
                     totals   => { %total_nr_of },
                    };
        $scr->at(0,0)->clreol();
        $scr->bold()->cyan->puts('Directory Pathname: ')->normal();
        $scr->cooked();
        chop($currentdir=<STDIN>);
        $scr->raw();
        $position_at='.';
        $refresh=2;
    }
    if ( !chdir $currentdir ) {
        &display_error("$currentdir: $!");
        &init_header($multiple_mode);
        chop($currentdir=`pwd`);
        $refresh=0;
    }
    &init_title($swap_mode,$uid_mode);
    return $refresh;
}

sub handleentry {
    local $_=$_[0];
    my ($tempptr,$nextdir,$success,$direction);
    if ( /^kl|h|\e$/i ) {
        $nextdir='..';
        $direction='up';
    } else {
        $nextdir=$currentfile{name}; 
        $direction= $nextdir eq '..' ? 'up' : 'down';
    }
    return 0 if ($nextdir eq '.');
    return 0 if ($currentdir eq '/' && $direction eq 'up');
    return 0 if !&ok_to_remove_marks;
    $success = chdir($nextdir);
    if ($success && $direction =~ /up/ ) {
        $position_at=&basename($currentdir);
    } elsif ($success && $direction =~ /down/) {
        $position_at='..';
    }
    unless ($success) {
        &display_error($!);
        &init_header($multiple_mode);
    }
    return $success;
}

##########################################################################
# directory browsing

sub stat_entry { # path_of_entry, selected_flag
    # the second argument is used to have the caller specify whether the
    # 'selected' field of the file info should be cleared (when reading
    # a new directory) or kept intact (when re-statting)
    my ($entry,$selected_flag) = @_;
    my ($ptr,$too_long,$target);
    my ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size);
    my ($atime,$mtime,$ctime,$blksize,$blocks);
   ($device,$inode,$mode,$nlink,$uid,$gid,$rdev,$size,
    $atime,$mtime,$ctime,$blksize,$blocks) = lstat $entry;
    if (!defined $user{$uid})  { $user{$uid}=$uid }
    if (!defined $group{$gid}) { $group{$gid}=$gid }
    $ptr = { name     => $entry,         device   => $device,
             inode    => $inode,         mode     => &mode2str($mode),
             uid      => $user{$uid},    gid      => $group{$gid},
             nlink    => $nlink,         rdev     => $rdev,
             size     => $size,          atime    => $atime,
             mtime    => $mtime,         ctime    => $ctime,
             blksize  => $blksize,       blocks   => $blocks,
             selected => $selected_flag };
    $ptr->{type}     = substr($ptr->{mode},0,1);
    $ptr->{target}   = $ptr->{type} eq 'l' ? ' -> '.readlink($ptr->{name}) : '';
    $ptr->{display}  = $entry.$ptr->{target};
#    $ptr->{too_long} = (' ','+')[length($ptr->{display})>$maxfilenamelength];
    $ptr->{too_long} = length($ptr->{display})>$maxfilenamelength ? '+' : ' ';
    $total_nr_of{ $ptr->{type} }++;
    if ($ptr->{type} =~ /[bc]/) {
        $ptr->{size}=sprintf("%d",$rdev/256).$majorminorseparator.($rdev%256);
    }
    return $ptr;
}

sub getdircontents { # (current)directory
    my (@contents,@allentries,$entry);
    &init_header($multiple_mode);
    &init_title($swap_mode,$uid_mode);
    if ( opendir CURRENT,"$_[0]" ) {
        @allentries=readdir CURRENT;
        closedir CURRENT;
    } else {
        @allentries=('.','..');
        &display_error("Cannot read . : $!");
        &init_header($multiple_mode);
    }
    if ($#allentries>$slowentries) {
        $scr->at($baseline,2)->bold()->puts('Please Wait')->normal();
    }
    foreach $entry (@allentries) {
        # have the mark cleared on first stat with ' '
        push @contents,&stat_entry($entry,' ');
    }
    return @contents;
}

sub printdircontents { # @contents
    foreach my $i ($baseindex .. $baseindex+$screenheight) {
        unless ($i > $#_) {
            $scr->at($i+$baseline-$baseindex,0)->puts(&fileline(%{$_[$i]}));
            &applycolor($i+$baseline-$baseindex,0,%{$_[$i]});
        } else {
            $scr->at($i+$baseline-$baseindex,0)
                ->puts(' 'x($screenwidth-$datecol-1));
        }
    }
}

sub countdircontents {
    %total_nr_of   = 
    %selected_nr_of=(  d=>0, l=>0, '-'=>0, D=>0, bytes=>0,
                       c=>0, b=>0, 's'=>0, p=>0 );
    foreach my $i (0..$#_) {
        $total_nr_of{$_[$i]{type}}++;
        $selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
    }
}

sub position_cursor {
    local $_;
    $currentline=0;
    $baseindex=0;
    # this line corrects for directories with no entries at all
    # (sometimes the case on NTFS filesystems)
    if ($#dircontents<0) { push @dircontents,{name => '.'} }
    for (0..$#dircontents) {
        if ($position_at eq $dircontents[$_]{name}) { $currentline=$_ , last };
    }
    $position_at='';
    &validate_position;
}

sub resizehandler {
    $wasresized=0;
    &handlefit;
    &validate_position;
}

sub recalc_ptr {
    $position_at='.';
    &position_cursor;
    return $dircontents[$currentline+$baseindex];
}

sub redisplayscreen {
    &init_frame($multiple_mode, $swap_mode, $uid_mode);
    $scr->at(1,0)->puts(&pathline($currentdir,$disk{'device'}));
    if ($position_at ne '') { &position_cursor }
    &printdircontents(@dircontents);
    &disk_info(%disk);
    &dir_info(%total_nr_of);
    &mark_info(%selected_nr_of);
    &user_info;
    &date_info($dateline,$screenwidth-$datecol);
}

sub browse {
    local $currentdir;
    local %disk;
    my ($returncode,@dflist,$key);
    my $quitting=0;

    # collect info

    chop($currentdir=`pwd`);
    local %total_nr_of   =( d=>0, l=>0, '-'=>0,
                            c=>0, b=>0, 's'=>0, p=>0, D=>0 );
    local %selected_nr_of=( d=>0, l=>0, '-'=>0, bytes=>0,
                            c=>0, b=>0, 's'=>0, p=>0, D=>0 );
    local @dircontents = sort as_requested (&getdircontents($currentdir));
    chop (@dflist=`df -k .`);
    @disk{qw/device total used avail/} =
         split ( /\s+/, ( grep !/filesys/i, @dflist )[0] );
    $disk{'avail'} !~ /%/ or $disk{'avail'}=$disk{'total'}-$disk{'used'};

    # now just reprint screen

    DISPLAY: {
        &redisplayscreen;
#        $scr->flush_input();

        STRIDE: for (;;) {
            %currentfile=%{ $dircontents[$currentline+$baseindex] || &recalc_ptr };
            &highlightline(1);
            until ($scr->key_pressed(1)) { 
                if ($wasresized) { &resizehandler; }
                &date_info($dateline,$screenwidth-$datecol);
                $scr->at($currentline+$baseline,0);
            }
            $key = $scr->getch();
            &highlightline(0);
            KEY: for ($key) {
                /^q$/i and
                    &handlequit ? do { $quitting=1, last STRIDE }
                                : do { &init_header($multiple_mode), last KEY };
                /^\cF|\cB|\cD|\cU|ku|kd|pgup|pgdn|home|end|[-+jk]$/i and 
                    &handlemove($_) and &printdircontents(@dircontents),
                    last KEY;
                /^kr|kl|[hl\e]$/i and
                    &handleentry($_) ? last STRIDE : last KEY;
                /^s|\r$/ and
                    $dircontents[$currentline+$baseindex]{type} eq 'd'
                       ? do { &handleentry($_) ? last STRIDE : last KEY }
                       : do { if (/\r/ && $currentfile{mode} =~ /x/)
                                   { &handleenter, redo DISPLAY }
                              else { &handleshow,  redo DISPLAY }
                            };
                       # what will we do with symlinks here?
                /^k5$/ and
                    &ok_to_remove_marks ? last STRIDE : last KEY;
                /^k9$/i and
                    &toggle($uid_mode),
                    &printdircontents(@dircontents),
                    &init_title($swap_mode,$uid_mode),
                    last KEY;
                /^k10$/ and
                    &toggle($multiple_mode),
                    &init_header($multiple_mode),
                    last KEY;
                /^ $/ and
                    &handleselect,
                    &handlemove($_) and &printdircontents(@dircontents),
                    last KEY;
                /^e$/i and
                    &handleedit, redo DISPLAY;
                /^t$/i and
                    &handletime ? redo DISPLAY : do {
                        &init_header($multiple_mode),
                        last KEY;
                    };
                /^p$/i and
                    &handleprint, redo DISPLAY;
                /^a$/i and
                    &handlechmod ? redo DISPLAY : do {
                        &init_header($multiple_mode),
                        last KEY;
                    };
                /^k8$/ and
                    &handleselect, last KEY;
                /^v$/i and
                    &handleview, last KEY; # redo DISPLAY;
                /^d$/i and
                    &handledelete ? redo DISPLAY : do {
                        &init_header($multiple_mode),
                        last KEY;
                    };
# from this point: test if display is updated correctly
                /^c$/i and
                    &handlecopy ? redo DISPLAY
                                : do { &init_header($multiple_mode),last KEY };
                /^r$/i and
                    &handlerename, last STRIDE;
                /^u$/i and
                    &handlechown ? redo DISPLAY : do {
                        &init_header($multiple_mode),
                        last KEY;
                    };
                /^[yo]$/i and
                    &handlecommand($_), redo DISPLAY;
                /^m$/i and
                    &handlemore ? last STRIDE : redo DISPLAY;
                /^[ix]$/i and
                    &handleinclude($_) ? redo DISPLAY : last KEY;
                /^k1$/ and &handlehelp, &credits, redo DISPLAY;
                /^k3$/ and &handlefit, last KEY;
                /^k4$/ and $scr->colorizable(!$scr->colorizable()),
                           redo DISPLAY;
                /^k6$/ and
                    &handlesort, redo DISPLAY;
                /^k7$/ and
                    do { $returncode = &handleswap },
                    do { if    ($returncode==1) { redo DISPLAY }
                         elsif ($returncode==2) { last STRIDE }
                         else { last KEY }
                       };
                /@/ and do {
                    $scr->at(0,0)->clreol()->cyan()->puts("Enter Perl command:")
                        ->at(1,0)->normal()->clreol()->cooked();
                    $cmd=<STDIN>; 
                    $scr->raw();
                    eval $cmd;
                    &display_error($@) if $@;
                    redo DISPLAY;
                };
            } # KEY
        }   # STRIDE
    }     # DISPLAY 
    return $quitting;
}      # sub browse

################################################################################
# void main (void)
                                                                               #
################################################################################

$SIG{WINCH} = sub { $wasresized=1; };
$scr= new Term::ScreenColor;
$scr->clrscr();

&read_pfmrc;

%user =%{&init_uids};
%group=%{&init_gids};
$swap_mode = $multiple_mode = 0;

if ($scr->getrows()) { $screenheight=$scr->getrows()-$baseline-2 }
if ($scr->getcols()) { $screenwidth =$scr->getcols() }
&init_frame(0,0,$uid_mode);
# uid_mode coming from .pfmrc

$ARGV[0] and chdir($ARGV[0]) || do {
    $scr->at(1,0)->clreol();
    &display_error("$ARGV[0]: $! - using .");
    $scr->key_pressed($errordelay); # effectively double delay
    &init_header(0);
};

MAIN: {
    $multiple_mode=0;
    redo MAIN unless &browse;
}

&goodbye;

##########################################################################
# Pod Documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [directory]>

=head1 DESCRIPTION

PFM is a terminal-based file manager, not unlike Midnight Commander.
This version was based on PFM.COM 2.32, originally written for MS-DOS
by Paul R. Culley and Henk de Heer.

All PFM commands are one- or two-letter commands (case insensitive).
PFM operates in two modes: single file mode and multiple file mode.
In single file mode, the command corresponding to the keypress will be
executed on the file next to the cursor only. In multiple file mode,
the command will apply to all marked files. You may switch modes by
pressing B<F10>.

Note that in the following descriptions, B<file> can mean any type
of file, not just plain regular files. These will be referred to as
B<regular files>.

=head1 NAVIGATION

=over

Navigation through directories may be achieved by using the arrow keys,
the vi cursor keys (B<hjkl>), B<->, B<+>, B<PgUp>, B<PgDn>, B<home>,
B<end>, B<CTRL-F> and B<CTRL-B>. Pressing B<ESC> will take you one
directory level up. Pressing B<ENTER> while on a directory will take
you into the directory. Pressing B<SPACE> will both mark the current
file and advance the cursor.

=back

=head1 COMMANDS

=over

=item B<Attrib>

Changes the mode of the file if you are the owner. Use a '+' to add
a permission, a '-' to remove it, and a '=' specify the mode exactly,
or specify the mode numerically. Note that the mode on a symbolic link
cannot be set. Read the chmod(1) page for more details.

=item B<Copy>

Copy current file. You will be prompted for the destination file name. In
multiple-mode, beware that you don't copy files to the same destination
file. Specify the destination name with escapes (see the B<O> command below).

=item B<Delete>

Delete a file or directory.

=item B<Edit>

Edit a file with your external editor. You can specify an editor with the
environment variable $EDITOR or in the F<.pfmrc> file, else vi(1) is used.

=item B<Include>

Allows you to mark a group of files which meet a certain criterion:
Every file, Oldmarks (reselects any files which were previously selected
and now bear an I<oldmark> '.'), User (only files owned by you) or Files
only (prompts for a regular expression which the filename must match).
Oldmarks may be used to do multifile operations on a group of files
more than once. If you Include Every, dotfiles will be included as well,
except for the B<.> and B<..> entries.

=item B<More>

Presents you with a choice of operations not related to the current
files. Use this to config PFM, edit a new file, make a new directory,
or view a different directory. See More Commands below. Pressing ESC
will take you back to the main menu.

=item B<cOmmand>

Allows execution of a shell command on the current files. Entering an
empty line will activate a copy of your default login shell until the
'exit' command is given. After the command completes, pfm will resume.
You may abbreviate the current filename as B<ESC>2, the current filename
without extension as B<ESC>1, the current directory path as B<ESC>3, and
the swap directory path (see B<F7> command) as B<ESC>5.

=item B<Print>

Print the specified file on the default system printer by piping it
through your print command (default lpr(1)). No formatting is done.
You may specify a print command in your F<.pfmrc> (see below).

=item B<Quit>

Exit pfm. You may specify in your F<$HOME/.pfmrc> whether pfm will ask for
confirmation (confirmquit:always|never|marked). 'marked' means you will
only be asked for confirmation if there are any marked files in the
current directory.

=item B<Rename>

Change the name of the file to the name specified. A different pathname and
filename in the same filesystem is allowed. In multiple-file mode, the new name
MUST be a directoryname or a name containing escapes (see B<cOmmand> above).

=item B<Show>

Displays the contents of the current file or directory on the screen.
You can choose which pager to use for file viewing with the environment
variable $PAGER, or in the F<.pfmrc> file.

=item B<Time>

Change date and time of the file. The format used is converted to a
format which touch(1) can use.

=item B<Uid>

Change ownership of a file. Some systems may not allow normal users to
change ownership.

=item B<View>

View the complete long filename. For a symbolic link, also displays the
target of the symbolic link.

=item B<eXclude>

Allows you to erase marks on a group of files which meet a certain
criterion: Every (all files), Oldmarks (files which have an I<oldmark>,
User (only files owned by you) or Files only (prompts for a regular
expression which the filename must match). If you eXclude Every,
dotfiles will be excluded as well, except for the B<.> and B<..> entries.

=item B<Your command>

Like B<O> command above, except that it uses your preconfigured
commands. Filenames may be abbreviated with escapes as in cB<O>mmand.
Commands can be preconfigured by entering them in the configuration file as
a I<letter>:I<command> line, e.g.

 T:tar tvfz ^[2

=back

=head1 MORE COMMANDS

=over

=item Config PFM

This option will open the F<.pfmrc> configuration file with your preferred
editor.

=item Edit new file

You will be prompted for the new file name, then your editor will
be spawned.

=item Make new directory

Specify a new directory name and PFM will create it for you. Furthermore,
if you don't have any files marked, your current directory will be set
to the newly created directory. If you don't want that, you will have
to create the directory using the B<O> command.

=item Show new directory

You will have to enter the new directory you want to view. Just pressing
ENTER will take you to your home directory. Be aware that this option
is different from B<F7> because this will not change your current swap
directory status.

=back

=head1 MISCELLANEOUS and FUNCTION KEYS

=over

=item B<F1>

Display help and licence information.

=item B<F3>

Fit the file list into the current window. PFM attempts to refresh the
display when the window size changes, but should this fail, then press F3.

=item B<F4>

Toggle the use of color.

=item B<F5>

Current directory will be reread. Use this when the contents of the
directory have changed. This will erase all marks!

=item B<F6>

Allows you to re-sort the directory listing. You will be presented by
a number of sort modes.

=item B<F7>

Swaps the display between primary and secondary screen. When switching
from primary to secondary, you are prompted for a path to show.
When switching back by pressing B<F7> again, the original contents are
displayed unchanged. Header text changes color when in secondary screen.
While in the secondary screen, you may specify the swap directory from
the first screen in commands as B<ESC>5

=item B<F8>

Toggles the include flag (mark) on an individual file. Space toggles the
flag and moves to the next file entry.

=item B<F9>

Toggle the display mode between either user id, group id, and link count,
or date, time, and inode number.

=item B<F10>

Switch between single-file and multiple-file mode.

=item B<ENTER>

Displays the contents of the current file or directory on the screen.
If the current file is executable, this will execute the command.
Be very careful with this key when running pfm as root!

=item B<ESC>

Shows the parent directory of the shown dir (backup directory tree).

=back

=head1 OPTIONS

=over

You may specify a starting directory on the command line when invoking
pfm.

=back

=head1 WORKING DIRECTORY INHERITANCE

=over 

In order to have the current working directory "inherited" by the calling
process (shell), you may specify the I<cwdinheritance> option in the
configuration file. You will then have to call pfm using a function like
the following (add it to your .profile):

 pfm () {
        pfmcwdfile=`awk -F: '$1=="cwdinheritance" {print $2}' < ~/.pfmrc`
        /usr/local/bin/pfm $*
        if [ -n "$pfmcwdfile" ]; then 
                cd "`cat $pfmcwdfile`"
                rm -f $pfmcwdfile
                unset pfmcwdfile
        fi
 }

=back

=head1 ENVIRONMENT

=over 

=item B<$PAGER>

Identifies the pager with which to view text files. Defaults to less(1)
for Linux systems or more(1) for Unix systems.

=item B<$EDITOR>

The editor to be used for the B<E> command.

=item B<$SHELL>

Your default login shell, spawned by cB<O>mmand with an empty line.

=back

=head1 FILES

F<$HOME/.pfmrc>

=head1 BUGS

Beware of the key repeat! When key repeat sets in, you may have more
keyclicks in the buffer than expected.

=head1 AUTHOR

Rene Uittenbogaard (ruittenbogaard@profuse.nl)

=head1 SEE ALSO

The documentation on PFM.COM . The mentioned man pages for chmod(1),
less(1), lpr(1), touch(1). The man page of B<ScreenColor.pm(3)>

=cut
