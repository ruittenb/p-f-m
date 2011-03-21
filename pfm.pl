#!/usr/bin/env perl
#
# @(#) pfm.pl 14-03-1999 v0.52
#
# Author:      Rene Uittenbogaard
# Usage:       pfm.pl [directory]
# Descriptiom: Personal File Manager for Linux
# Version:     v0.52
# Date:        14-03-1999
# 

require Term::Screen;
use Carp;

my $screenheight=20;

sub pathline {
    croak "usage: pathline (path, device)" unless @_;
    $^A = "";
    formline(<<'_eoPathFormat_',@_);
@<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< [@<<<<<<<<<<]
_eoPathFormat_
    return $^A;
}

sub uidline {
    croak "usage: tdline (filename,size,uid,gid,linkcount,mode)" unless @_;
    $^A = "";
    formline(<<'_eoUidFormat_',@_);
  @<<<<<<<<<<<<<<<<<<< @>>>>>>  @<<<<<<< @<<<<<<< @##  @<<<<<<<<<
_eoUidFormat_
    return $^A;
}

sub tdline {
    croak "usage: tdline (filename,size,month,day,time,inode,mode)" unless @_;
    $^A = "";
    formline(<<'_eoTDFormat_',@_);
  @<<<<<<<<<<<<<<<<<<< @>>>>>>  @<< @#  @<<<<<@######  @<<<<<<<<<
_eoTDFormat_
    return $^A;
}

sub fileline {
    local ($_)=@_;
    if ($uid_mode) {
        return &uidline( (split(/\s+/))[9,5,4,3,2,1] );
    } else {
        return &tdline( (split(/\s+/))[9,5,6,7,8,0,1] );
    }
}

sub print_with_shortcuts {
    local $_ = $_[0];
    my $reminder;
    while (/(.)/g) {
        $reminder=$1;
        if ($reminder eq uc($reminder)) {
            $scr->bold()->puts($reminder);
        } else {
            $scr->normal()->puts($reminder);
        }
    }
    $scr->normal();
}

sub frame_init {
    my $kolomkoppen=<<_eoKop_;
  filename.ext            size  date    time    inode  attrib          disk info
  filename.ext            size  userid   groupid lnks  attrib          disk info
_eoKop_
    my $firstlines=<<_eoFirst_;
Attribute Time Copy Delete Edit Print Rename Show Your cOmmands Quit Uids More  
Multiple Include eXclude Attribute Time Copy Delete Print Rename Your cOmmands
_eoFirst_
    my $footer;
    chop($footer=<<_eoFunction_);
F1-Help F5-Reread F6-Sort F7-Swap F8-In/Exclude F10-Multiple -/+ hjkl PgUp PgDn 
_eoFunction_
    @firstlines=split(/\n/,$firstlines);
    @kolomkoppen=split(/\n/,$kolomkoppen);
    $scr->at(0,0);
    &print_with_shortcuts($firstlines[$multiple_mode]);
    $scr->reverse();
    if ($multiple_mode) { $scr->at(0,0)->puts("Multiple"); }
    $scr->at(2,0)->puts($kolomkoppen[$uid_mode]);
    $scr->at(24,0)->puts($footer);
    $scr->normal();
}

sub highlightline { # true/false
#    $scr->at(24,0)->puts("baseindex: $baseindex, currentline: $currentline");
    $scr->at($currentline+3,0);
    $scr->bold() if $_[0];
    $scr->puts(&fileline($dircontents[$baseindex+$currentline]));
    $scr->normal()->at($currentline+3,0);
}

sub infoline { # number, description
    $^A = "";
    formline('@##### @<<<<<',@_);
    return $^A;
}

sub disk_info { # total, used, avail
    my @desc=('K tot','K usd','K avl');
    my @values=@_;
    my $startline=4;
    $scr->at($startline-1,70)->puts('Disk space');
    foreach (0..2) {
        if ( $values[$_] > 99999 ) {
                $values[$_] /= 1024;
                $desc[$_] =~ tr/KMGT/MGTP/;
                redo;
        }
        $scr->at($startline+$_,68)->puts(&infoline($values[$_],$desc[$_]));
    }
}

sub dir_info { # dirs,files,symlinks,spec
    my @desc=qw/dirs files symln spec/;
    my @values=@_;
    my $startline=9;
    $scr->at($startline-1,71)->puts('Directory');
    foreach (0..3) {
        $scr->at($startline+$_,68)->puts(&infoline($values[$_],$desc[$_]));
    }
}

sub mark_info { # dirs,files,bytes,symlinks,spec
    my @desc=qw/dirs files bytes symln spec/;
    my @values=@_;
    my $startline=15;
    $scr->at($startline-1,68)->puts('Marked files');
    foreach (0..4) {
        $scr->at($startline+$_,68)->puts(&infoline($values[$_],$desc[$_]));
    }
}

sub date_info {
    my ($date,$time);
    my $datetime = `date +"%Y%m%d %H:%M:%S"`;
    ($date,$time) = split(/\s+/,$datetime);
    $scr->at(22,67)->puts("$date date");
    $scr->at(23,67)->puts("$time time");
}

sub as_requested { 
    my @a=split(/\s+/,$a);
    my @b=split(/\s+/,$b);
    SWITCH:
    for ($sort_mode) {
        /name/ and return $a[9]       cmp $b[9],       last SWITCH;
        /size/ and return $a[5]       <=> $b[5],       last SWITCH;
        /type/ and return $a[1].$a[9] cmp $b[1].$b[9], last SWITCH;
        /narv/ and return $b[9]       cmp $a[9],       last SWITCH;
        /sirv/ and return $b[5]       <=> $a[5],       last SWITCH;
        /tyrv/ and return $b[1].$b[9] cmp $a[1].$a[9], last SWITCH;
#        /nami/ and return lc($a[9])   cmp lc($b[9]),   last SWITCH;
#        /nami/ and return $ai         cmp $bi,         last SWITCH;
#        /nari/ and return $bi         cmp $ai,         last SWITCH;
    }
}

sub getdircontents {
    $scr->at(3,2)->bold()->puts('Please Wait')->normal();
    chop (@contents=`ls -ail $_[0]`);
    my @parsed_contents;
    foreach (@contents) {
        s/^\s*//;  # remove initial whitespace for split
        s/^(\d+\s+ # skip inode number
          [bc]     # make sure this is a block- or character file
          .*?      # skip as few chars as possible
          \b\d+)   # start of major number - comma assures special file
          ,\s+     # this is the whitespace we want to delete!
          /$1\//x; # delete it
        push @parsed_contents, $_ unless /^total/;
    }
    return @parsed_contents;
}

sub printdircontents {
    &dir_info(3,2,4,0); # %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    foreach my $i ($baseindex .. $baseindex+$screenheight) {
        last if $i > $#_;
        $scr->at($i+3-$baseindex,0)->puts(&fileline($_[$i]));
    }
}

sub handlequit {
    $scr->at(0,0)->bold()->clreol();
    $scr->puts("Are you sure you want to quit? [Y/N] ")->normal();
    my $key = $scr->getch();
    return $key =~ /y/i;
}

sub handlemove {
    local $_=$_[0];
    my $redraw=0;
    my $displacement = -10*(/^-$/)  -(/^ku|k$/) -($screenheight-1)*(/pgup/)
                       +10*(/^\+$/) +(/^kd|j$/) +($screenheight-1)*(/pgdn/);
    $currentline += $displacement;
    if ( $currentline <0 ) {
        $baseindex += $currentline;
        $baseindex <0 and $baseindex=0;
        $currentline =0;
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

sub browse {
    local $baseindex=0;
    local $currentline=0;
    $multiple_mode=0;
    $scr->at(1,0)->puts(&pathline(@_));
    local @dircontents = sort as_requested (&getdircontents($_[0]));
    &printdircontents(@dircontents);

    &mark_info(2,0,120,0,0); # %%%%%%%%%%%%%%%%%%%%%%%%%%%

    STRIDE: for (;;) {
        &highlightline(1);
        $scr->flush_input();
        do { 
            date_info;
            $scr->at($currentline+3,0);
        } until ($scr->key_pressed(1));
        $key = $scr->getch();
        &highlightline(0);
        KEY: for ($key) {
            /^q$/i and
                &handlequit ? last STRIDE : &frame_init,
                last KEY;
            /^ku|kd|pgup|pgdn|[-+jk]$/i and 
                &handlemove($_) and &printdircontents(@dircontents),
                last KEY;
            /^u$/i and
                $uid_mode= !$uid_mode,
                &printdircontents(@dircontents), &frame_init,
                last KEY;
            /^k10$/ and
                $multiple_mode= !$multiple_mode,
                &frame_init,
                last KEY;
        }
    } 
}

################################################################################
##                                                                            ##
##                               void main (void)                             ##
##                                                                            ##
################################################################################

$scr= new Term::Screen;

$scr->clrscr();
$sort_mode='name';
$multiple_mode=0;
$uid_mode=0; # 0=date/time; 1=uid/gid

&frame_init;

$ARGV[0] ? $currentdir=shift : chop($currentdir=`pwd`);

MAIN: {
    ($device,$disktotal,$diskused,$diskavail) =
            split(/\s+/,`df -k $currentdir|grep -iv filesys`);
    &disk_info($disktotal,$diskused,$diskavail);
    &browse($currentdir,$device);
}

$scr->at(0,0)->puts(<<_eoGoodbye_);
                    Goodbye from your Personal File Manager!                    
_eoGoodbye_
$scr->at(24,0)->clreol();

################################################################################
##                                                                            ##
##        Screen module demo                                                  ##
##                                                                            ##
################################################################################
# 
#$scr = new Term::Screen;
#
##test clear screen and output
#$scr->clrscr();
#$scr->puts("Test series for Screen.pm module for perl5");
#
## test cursor movement, output and linking together
#$scr->at(2,3)->puts("1. Should be at row 2 col 3 (upper left is 0,0)");
#
##test current position update
#$r = $scr->{'r'}; $c = $scr->{'c'};
#$scr->at(3,0)->puts("2. Last position $r $c -- should be 2 50.");
#
##test rows and cols ( should be updated for signal )
#$scr->at(4,0)->puts("3. Screen size: " . $scr->{'rows'} . " rows and " . 
#                                           $scr->{'cols'} . " columns.");
## test standout and normal test
#$scr->at(6,0);
#$scr->puts("4. Testing ")->reverse()->puts("reverse");
#$scr->normal()->puts(" mode, ");
#$scr->bold()->puts("bold")->normal()->puts(" mode, ");
#$scr->bold()->reverse()->puts("and both")->normal()->puts(" together.");
#
## test clreol 
## first put some stuff up
#$line = "0---------10--------20--------30--------40--------50--------60--------70-------";
#$scr->at(7,0)->puts("5. Testing clreol - " . 
#                      "   The next 2 lines should end at col 20 and 30.");
#for (8 .. 10) {$scr->at($_,0)->puts($line);}
#$scr->at(8,20)->clreol()->at(9,30)->clreol();
#
## test clreos
#for (11 .. 20) { $scr->at($_,0)->puts($line); }
#$scr->at(11,0)->puts("6. Clreos - Hit a key to clear all right and below:");
#$scr->getch();
#$scr->clreos();
#
##test insert line and delete line
#$scr->at(12,0)->puts("7. Test insert and delete line - 15 deleted, and ...");
#for (13 .. 16) { $scr->at($_,0)->puts($_ . substr($line,2)); }
#$scr->at(15,0)->dl();
#$scr->at(14,0)->il()->at(14,0)->puts("... this is where line 14 was");
#
## test key_pressed
#$scr->at(18,0)->puts("8. Key_pressed - Don't Hit a key in the next 5 seconds: ");
#if ($scr->key_pressed(5)) { $scr->puts("HEY A KEY WAS HIT"); } 
#  else { $scr->puts("GOOD - NO KEY HIT!"); }
#$scr->at(19,0)->puts("Hit a key in next 15 seconds: ");
#if ($scr->key_pressed(15)) { $scr->puts("KEY HIT!"); } 
#  else { $scr->puts("NO KEY HIT"); }
#
## test getch
## clear buffer out
#$scr->flush_input();
#$scr->at(21,0)->puts("Testing getch, Enter Key (q to quit): ")->at(21,40);
#$ch = '';
#while(($ch = $scr->getch()) ne 'q') 
#{
#  if (length($ch) == 1) 
#    {
#      $scr->at(21,50)->clreol()->puts("ord of char is: ");
#      $scr->puts(ord($ch))->at(21,40);
#    }
#  else 
#    {
#      $scr->at(21,50)->clreol()->puts("function value: $ch");
#      $scr->at(21,40);
#    }
#}
#
#$scr->at(22,0);
#
# 

################################################################################
##                                                                            ##
##        Personal File Manager in Perl                                       ##
##                                                                            ##
################################################################################

=pod


Dos version
1-------10--------20--------30--------40--------50--------60--------70--------80
Attribute Time Copy Delete Edit Print Rename Show Your cOmmands Quit More
C:\WINNT\PROFILES\RUITTE~1\DESKTOP\                                [Apps       ]
     filename ext        size    date      time    attrib    disk & system info
     ..                 <DIR>  03/07/99  04:33:34  [    ]            Disk space
     INCOMING           <DIR>  03/04/99  11:57:44  [    ]   1,023,967,232 total
     OUTGOING           <DIR>  03/03/99  08:54:40  [    ]     398,819,328 used
     GROFF              <DIR>  03/07/99  13:22:52  [    ]     625,147,904 avail
     3FLOPP~1 LNK         245  03/03/99  17:11:04  [BRSH]
     BAAN     LNK         263  02/08/99  12:45:14  [B   ]             Directory
     BOBO     LNK         305  01/15/99  23:17:14  [B   ]               3 dirs
     DIAL-U~1 LNK         120  01/18/99  19:29:06  [B   ]              14 files
     FDISK    OUT       1,072  02/25/99  09:32:34  [B   ]         425,984 used
     FDISK~1  MEN           0  03/06/99  18:45:04  [B   ]
     KENNIS~1 LNK         364  03/06/99  11:44:32  [B   ]          Marked files
     LEASEA~1 LNK         332  03/06/99  12:34:34  [B   ]               0 files
     PCPRIV~1 LNK         334  03/04/99  22:42:56  [B   ]               0 bytes
     PCREGE~1 LNK         332  03/04/99  11:58:22  [B   ]
     PROFUSE  LNK         311  03/06/99  12:30:26  [B   ]     640 kb DOS memory
     SHRED    PIF       2,855  10/30/98  20:31:08  [B   ]         635,008 avail
     TO-CD4   LNK         345  02/21/99  14:46:40  [B   ]         613,792 free
     WINZIP   LNK         405  12/01/98  14:16:28  [B   ]
                                                                 03/07/99  date
                                                                 13:24:18  time
 
 F1-Help F5-Reread F6-Sort F7-Swap F8-In/Exclude F10-Multiple -/+  PgUp PgDn

--------------------------------------------------------------------------------
Unix version
1-------10--------20--------30--------40--------50--------60--------70--------80
Attribute Time Copy Delete Edit Print Rename Show Your cOmmands Quit Uids More
/home/rene                                                         [/dev/hda7  ]
  filename.ext            size  date    time    inode  attrib          disk info
  .                       1024  Mar 14  01:27  341369  drwxr-xr-x     Disk space
  ..                      1024  Mar 12  19:46    4234  drwxr-xr-x    50717 K tot
  .bash_history           8746  Mar 13  23:49     758  drw-rw-r--    31764 K usd
  .bash_profile            113  Mar 13  23:49     759  -rw-r--r--    16334 K avl
  .fvwm2rc               12331  Mar 10  14:20    1240  -rw-r----- 
  .pfm.swp               28672  Feb 24  01:06     758  -rw-------     Directory
  .profile                  13  Feb 28  12:30     757  lrwxrwxrwx        3 dirs
  .exrc                     21  Mar 12  20:33     721  -rw-rw-r--       10 files
  Screen-1.00.tar.gz      7493  Mar 11  12:50    1234  -rw-------        4 symln
  TStest.pl               2687  Feb 25  13:10    1233  -rwxr-xr-x        0 spec
  filename.ext            size  userid   groupid lnks  attrib   
  pfm.nolol              13309  rene     users      1  -rwxr-xr-x   Marked files
  pfm.pl                 11538  rene     users      1  -rwxr-xr-x        0 dirs
  services.linux          4534  rene     users      1  -rw-r--r--        0 files
  services.winnt          5855  rene     users      1  -rw-rw-r--        0 bytes
  strlen.pl                100  rene     users      1  -rwxr-xr-x        0 symln
  termscreen.pl             43  rene     users      1  -rwxr-xr-x        0 spec
  test                    1024  rene     users     13  drwxrwxr-x
                                                                   19990314 date
                                                                   13:24:18 time
F1-Help F5-Reread F6-Sort F7-Swap F8-In/Exclude F10-Multiple -/+  PgUp PgDn
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
messages
1-------10--------20--------30--------40--------50--------60--------70--------80


Every; ATTribute; Oldmarks; After, Before, or Ignore Date and Time:
Config PFM Edit new file Make new dir Show new drive/dir ESC to main menu

Put Date/Time: 01/01/93 00:00:00
New name: E:\BACKUP\PREFS
Directory Pathname: A:
Are you sure you want to delete [Y/N]? N
03 Error during edit - hit 'ESC' to continue or 'F1' for help
Enter DOS command (F1=name, F2=name.ext, F3=path, F4=drive, F5=swap path):
cd c:\winnt\profiles\ruitte~1\desktop


Color, Fixed or Variable, Showmode, Ruler, TeXt, Tab's, +n or -n lines, Quit
F1-Help F2-Search F4-Again   Move: (Ctrl-) hjkl PgUp PgDn Home End          1, 1

Enter one of the Highlighted chars at right:
C:\PROGRA~1\BIN\                                                   [Apps       ]
    filename ext        size    date      time    attrib    your commands
    ..                 <DIR>  03/12/99  12:22:06  [    ]    Z pkzip 1.zip 2
    ARJ250             <DIR>  10/30/98  22:57:44  [    ]    K diskut 2

=cut

