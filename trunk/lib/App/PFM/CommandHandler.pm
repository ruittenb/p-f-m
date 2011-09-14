#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::CommandHandler 1.30
#   
# Name:			App::PFM::CommandHandler
# Version:		1.30
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-13
#

##########################################################################

=pod

=head1 NAME

App::PFM::CommandHandler

=head1 DESCRIPTION

PFM Class for executing user commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::CommandHandler;

use base 'App::PFM::Abstract';

use App::PFM::Util			qw(:all);
use App::PFM::Directory 	qw(:constants); # imports the D_* and M_* constants
use App::PFM::History		qw(:constants); # imports the H_* constants
use App::PFM::Screen		qw(:constants); # imports the R_* constants
use App::PFM::Screen::Frame qw(:constants); # MENU_*, HEADING_*, and FOOTER_*

use POSIX qw(strftime mktime);
use Config;

use strict;
use locale;

use constant {
	FALSE	      => 0,
	TRUE	      => 1,
	QUOTE_OFF     => 0,
	QUOTE_ON      => 1,
	BUTTON_LEFT   => 0,
	BUTTON_MIDDLE => 1,
	BUTTON_RIGHT  => 2,
	SPAWNEDCHAR   => '*',
};

use constant NUMFORMATS => {
	'hex' => '%#04lx',
	'oct' => '%03lo',
};

use constant INC_CRITERIA => [
	'e' => 'Every',
	'o' => 'Oldmarks',
	'n' => 'Newmarks',
	'a' => 'After',
	'b' => 'Before',
	'g' => 'Greater',
	's' => 'Smaller',
	'u' => 'User',
	'f' => 'Files only',
	'.' => 'Dotfiles',
	'i' => 'Invert',
];

use constant CMDESCAPES => {
	'1' => 'name',
	'2' => 'name.ext',
	'3' => 'curr path',
	'4' => 'mountpoint',
	'5' => 'swap path',
	'6' => 'base path',
	'7' => 'extension',
	'8' => 'selection',
	'e' => 'editor',
#	'f' => 'fg editor', # don't advocate
	'p' => 'pager',
	'v' => 'viewer',
};

use constant FIELDS_TO_SORTMODE => [
	 n => 'n', # name
	'm'=> 'd', # mtime --> date
	 a => 'a', # atime
	's'=> 's', # size
	'z'=> 'z', # grand total (siZe)
	 p => 't', # perm --> type
	 i => 'i', # inode
	 l => 'l', # link count
	 v => 'v', # version(rcs)
	 u => 'u', # user
	 g => 'g', # group
	'*'=> '*', # mark
];

our ($_pfm);
our ($command);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm [, App::PFM::Screen $screen
[, App::PFM::Config $config [, App::PFM::OS $os ] ] ] )

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen, $config, $os) = @_;
	$_pfm    = $pfm;
	$self->{_screen} = $screen;
	$self->{_config} = $config;
	$self->{_os}     = $os;
	$self->{_clobber_mode} = 0;
}

=item _helppage(int $pageno)

Returns the text for a specific help page.

=cut

sub _helppage {
	my ($self, $page) = @_;
	my $prompt;
	if ($page == 1) {
		print <<'        _endPage1_';
--------------------------------------------------------------------------------
                          NAVIGATION AND DISPLAY KEYS                      [1/3]
--------------------------------------------------------------------------------
 k, up arrow     move one line up                 F1   help                     
 j, down arrow   move one line down               F2   go to previous directory 
 -, +            move ten lines                   F3   redraw screen            
 CTRL-E          scroll listing one line up       F4   cycle colorsets          
 CTRL-Y          scroll listing one line down     F5   reread directory         
 CTRL-U          move half a page up              F6   sort directory           
 CTRL-D          move half a page down            F7   toggle swap mode         
 CTRL-B, PgUp    move a full page up              F8   mark file                
 CTRL-F, PgDn    move a full page down            F9   cycle layouts            
 HOME, END       move to top, bottom              F10  toggle multiple mode     
 SPACE           mark file & advance              F11  restat file              
 l, right arrow  enter directory                  F12  toggle mouse mode        
 h, left arrow   leave directory                 -------------------------------
 ENTER           enter directory; launch          !    toggle clobber mode      
 ESC, BS         leave directory                  *    toggle radix for display 
---------------------------------------------     "    toggle pathmode          
 ?               help                             =    cycle idents             
 <               pan commands menu left           .    filter dotfiles          
 >               pan commands menu right          %    filter whiteouts         
--------------------------------------------------------------------------------
        _endPage1_
		$prompt = 'F1 or ? for manpage, arrows or BS/ENTER to browse ';
	} elsif ($page == 2) {
		print <<'        _endPage2_';
--------------------------------------------------------------------------------
                                  COMMAND KEYS                             [2/3]
--------------------------------------------------------------------------------
 a      Attribute (chmod)                w   remove Whiteout                    
 c      Copy                             x   eXclude                            
 d DEL  Delete                           y   Your command                       
 e      Edit                             z   siZe (grand total)                 
 f /    Find                             @   enter perl command (for debugging) 
 g      change symlink tarGet           ----------------------------------------
 i      Include                          ma  edit ACL                           
 L      sym/hard Link                    mb  make Bookmark                      
 m      More commands --->               mc  Configure pfm                      
 n      show Name                        me  Edit any file                      
 o      OS cOmmand                       mf  make FIFO                          
 p      Print                            mg  Go to bookmark                     
 q      quit                             mh  spawn sHell                        
 Q      quick quit                       mm  Make new directory                 
 r      Rename/move                      mp  show Physical path                 
 s      Show                             ms  Show directory (chdir)             
 t      change Time                      mt  show alTernate screen              
 u      change User/group (chown)        mv  Version status all files           
 v      Version status                   mw  Write history                      
--------------------------------------------------------------------------------
        _endPage2_
		$prompt = 'F1 or ? for manpage, arrows or BS/ENTER to browse ';
	} else {
		my $name = $self->{_screen}->colored('bold', 'pfm');
		my $version_message = $_pfm->{NEWER_VERSION}
			? "A new version $_pfm->{NEWER_VERSION} is available from"
			: "  New versions will be published on";
		print <<"        _endCredits_";
--------------------------------------------------------------------------------
                                     CREDITS                               [3/3]
--------------------------------------------------------------------------------

          $name for Unix and Unix-like operating systems.  Version $_pfm->{VERSION}
             Original idea/design: Paul R. Culley and Henk de Heer
             Author and Copyright (c) 1999-$_pfm->{LASTYEAR} Rene Uittenbogaard

       $name is distributed under the GNU General Public License version 2.
                    $name is distributed without any warranty,
             even without the implied warranties of merchantability
                      or fitness for a particular purpose.
                   Please read the file COPYING for details.

      You are encouraged to copy and share this program with other users.
   Any bug, comment or suggestion is welcome in order to improve this product.

  $version_message http://sourceforge.net/projects/p-f-m/

                For questions, remarks or suggestions about $name,
                 send email to: ruittenb\@users.sourceforge.net

--------------------------------------------------------------------------------
        _endCredits_
		$prompt = "F1 or ? for manpage, arrows or BS/ENTER to browse, "
				.	"any other key exit to $name ";
	}
	return $prompt;
}

=item _markednames(bool $do_quote)

Creates a list of names of marked files, for the B<=8> escape.

=cut

sub _markednames {
	my ($self, $qif) = @_;
	my $directory = $_pfm->state->directory;
	my @res =	map  {
					$directory->exclude($_, M_OLDMARK);
					condquotemeta($qif, $_->{name});
				}
				grep { $_->{selected} eq M_MARK }
				@{$directory->showncontents};
	return @res;
}

=item _expand_replace(bool $do_quote, char $escapechar [, string
$name_no_extension, string $name, string $extension ] )

Does the actual escape expansion in commands and filenames
for one occurrence of an escape sequence.

All escape types B<=1> .. B<=8> escapes plus B<=e>, B<=f>, B<=p> and B<=v>
are recognized.  See pfm(1) for more information about the meaning of
these escapes.

=cut

sub _expand_replace {
	my ($self, $qif, $category, $name_no_extension, $name, $extension) = @_;
	for ($category) {
		/1/ and return condquotemeta($qif, $name_no_extension);
		/2/ and return condquotemeta($qif, $name);
		/3/ and return condquotemeta($qif, $_pfm->state->directory->path);
		/4/ and return condquotemeta($qif, $_pfm->state->directory->mountpoint);
		/5/ and $_pfm->state('S_SWAP')
			and return condquotemeta($qif,
                                $_pfm->state('S_SWAP')->directory->path);
		/6/ and return condquotemeta($qif,
                                    basename($_pfm->state->directory->path));
		/7/ and return condquotemeta($qif, $extension);
		/8/ and return join (' ', $self->_markednames($qif));
		/e/ and return condquotemeta($qif, $_pfm->config->{editor});
		/f/ and return condquotemeta($qif, $_pfm->config->{fg_editor});
		/p/ and return condquotemeta($qif, $_pfm->config->{pager});
		/v/ and return condquotemeta($qif, $_pfm->config->{viewer});
		# this also handles the special $e$e case - don't quotemeta() this!
		return $_;
	}
}

=item _expand_3456_escapes(bool $do_quote)

Expands all occurrences of B<=3> .. B<=6> escapes.

=cut

sub _expand_3456_escapes { # quoteif, command
	my ($self, $qif) = @_;
	*command = \$_[2];
	my $qe = quotemeta $_pfm->config->{e};
	# readline understands ~ notation; now we understand it too
	$command =~ s/^~(\/|$)/$ENV{HOME}\//;
	# ~user is not replaced if it is not in the passwd file
	# the format of passwd(5) dictates that a username cannot contain colons
	$command =~ s/^~([^:\/]+)/(getpwnam $1)[7] || "~$1"/e;
	# the next generation in quoting
	$command =~ s/$qe([^1278])/_expand_replace($self, $qif, $1)/ge;
}

=item _expand_escapes(bool $do_quote, stringref *command, App::PFM::File $file)

Expands all occurrences of all types of escapes.

=cut

sub _expand_escapes { # quoteif, command, \%currentfile
	my ($self, $qif, undef, $currentfile) = @_;
	*command	= \$_[2];
	my $name	= $currentfile->{name};
	my $qe		= quotemeta $_pfm->config->{e};
	my ($name_no_extension, $extension);
	# include '.' in =7
	if ($name =~ /^(.*)(\.[^\.]+)$/) {
		$name_no_extension = $1;
		$extension		   = $2;
	} else {
		$name_no_extension = $name;
		$extension		   = '';
	}
	# readline understands ~ notation; now we understand it too
	$command =~ s/^~(\/|$)/$ENV{HOME}\//;
	# ~user is not replaced if it is not in the passwd file
	# the format of passwd(5) dictates that a username cannot contain colons
	$command =~ s/^~([^:\/]+)/(getpwnam $1)[7] || "~$1"/e;
	# the next generation in quoting
	$command =~ s/$qe(.)/
		_expand_replace($self, $qif, $1, $name_no_extension, $name, $extension)
	/ge;
}

=item _multi_to_single(string $filename)

Checks if the destination of a multifile operation is a single file
(not allowed).

=cut

sub _multi_to_single {
	my ($self, $testname) = @_;
	my $e  = $_pfm->config->{e};
	my $qe = quotemeta $e;
	$self->{_screen}->set_deferred_refresh(R_PATHINFO);
	if ($_pfm->state->{multiple_mode} and
		$testname !~ /(?<!$qe)(?:$qe$qe)*${e}[127]/ and !-d $testname)
	{
		$self->{_screen}->at(0,0)->putmessage(
			'Cannot do multifile operation when destination is single file.'
		)->at(0,0)->pressanykey();
		#path_info(); # necessary?
		return 1;
	}
	return 0;
}

=item _followmode(App::PFM::File $file)

Fetches the mode of the file, or of the target if it is a symlink.

=cut

sub _followmode {
	my ($self, $file) = @_;
	return $file->{type} ne 'l'
		   ? $file->{mode}
		   : $file->mode2str((stat $file->{name})[2]);
}

=item _promptforboundarytime(char $key)

Prompts for entering a time determining which files should be
included (marked) or excluded (unmarked).

=cut

sub _promptforboundarytime {
	my ($self, $key) = @_;
	my $prompt = ($key eq 'a' ? 'After' : 'Before')
			   . " modification time CCYY-MM-DD hh:mm[.ss]: ";
	my $boundarytime;
	$self->{_screen}->at(0,0)->clreol()->cooked_echo();
	$boundarytime = $_pfm->history->input({
		history       => H_TIME,
		prompt        => $prompt,
		default_input => strftime ("%Y-%m-%d %H:%M.%S", localtime time),
	});
	# show_menu is done in handleinclude
	$self->{_screen}->raw_noecho();
	return mktime gmtime touch2time($boundarytime);
}

=item _promptforboundarysize(char $key)

Prompts for entering a size determining which files should be
included (marked) or excluded (unmarked).

=cut

sub _promptforboundarysize {
	my ($self, $key) = @_;
	my $prompt = ($key eq 'g' ? 'Minimum' : 'Maximum')
			   . " file size: ";
	my $boundarysize;
	$self->{_screen}->at(0,0)->clreol()->cooked_echo();
	$boundarysize = $_pfm->history->keyboard->readline($prompt);
	# show_menu is done in handleinclude
	$self->{_screen}->raw_noecho();
	$boundarysize =~ tr/0-9//dc;
	return $boundarysize;
}

=item _promptforwildfilename(char $key)

Prompts for entering a regular expression determining which files
should be included (marked) or excluded (unmarked).

=cut

sub _promptforwildfilename {
	my ($self, $key) = @_;
	my $prompt = 'Wild filename (regular expression): ';
	my $wildfilename;
	$self->{_screen}->at(0,0)->clreol()->cooked_echo();
	$wildfilename = $_pfm->history->input({
		history => H_REGEX,
		prompt  => $prompt,
	});
	# show_menu is done in handleinclude
	$self->{_screen}->raw_noecho();
	eval "/$wildfilename/";
	if ($@) {
		$self->{_screen}->display_error($@)
			->key_pressed($self->{_screen}->IMPORTANTDELAY);
		$wildfilename = '^$'; # clear illegal regexp
	}
	return $wildfilename;
}

=item _listbookmarks()

List the bookmarks from the %states hash.

=cut

sub _listbookmarks {
	my ($self) = @_;
	my $screen = $self->{_screen};
	my $printline       = $screen->BASELINE;
	my $filerecordcol   = $screen->listing->filerecordcol;
	my @heading         = $screen->frame->bookmark_headings;
	my $bookmarkpathlen = $heading[2];
	my $spacing         =
		' ' x ($screen->screenwidth - $screen->diskinfo->infolength);
	my ($dest, $spawned, $overflow);
	# headings
	$screen
		->set_deferred_refresh(R_SCREEN)
		->show_frame({
			headings => HEADING_BOOKMARKS,
			footer   => FOOTER_NONE,
		});
	# list bookmarks
	foreach (@{$_pfm->config->BOOKMARKKEYS}) {
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		$dest    = $_pfm->state($_);
		$spawned = ' ';
		if (ref $dest) {
			$dest    = $dest->directory->path . '/' . $dest->{_position};
			$dest    =~ s{/\.$}{/};
			$dest    =~ s{^//}{/};
			$spawned = SPAWNEDCHAR;
		}
		if (length($dest)) {
			($dest, undef, $overflow) = fitpath($dest, $bookmarkpathlen);
			$dest .= ($overflow ? $screen->listing->NAMETOOLONGCHAR : ' ');
		}
		$screen->at($printline++, $filerecordcol)
			->puts(sprintf($heading[0], $_, $spawned, $dest));
	}
	foreach ($printline .. $screen->BASELINE + $screen->screenheight) {
		$screen->at($printline++, $filerecordcol)->puts($spacing);
	}
}

##########################################################################
# constructor, getters and setters

=item clobber_mode( [ bool $clobber_mode ] )

Getter/setter for the clobber mode, which determines if files will be
overwritten without confirmation.

=cut

sub clobber_mode {
	my ($self, $value) = @_;
	$self->{_clobber_mode} = $value if defined $value;
	return $self->{_clobber_mode};
}

##########################################################################
# public subs

=item by_name()

Sorting routine: sorts files by name.

=cut

sub by_name {
	return $a->{name} cmp $b->{name};
}

=item alphabetically()

Sorting routine: sorts strings alphabetically, case-insensitive.

=cut

sub alphabetically {
	return uc($a) cmp uc($b) || $a cmp $b;
}


=item escape_midway()

Sorting routine: sorts digits E<lt> escape character E<lt> letters.

=cut

sub escape_midway {
	# the sorting of the backslash appears to be locale-dependant
	my $e = $_pfm->config->{e};
	if ($a eq "$e$e" && $b =~ /\d/) {
		return 1;
	} elsif ($b eq "$e$e" && $a =~ /\d/) {
		return -1;
	} else {
		return $a cmp $b;
	}
}

=item not_implemented()

Handles unimplemented commands.

=cut

sub not_implemented {
	my ($self) = @_;
	$self->{_screen}->at(0,0)->clreol()
		->set_deferred_refresh(R_MENU)
		->display_error('Command not implemented');
}

=item handle(App::PFM::Event $event)

Finds out how an event should be handled, and acts on it.

=cut

sub handle {
	my ($self, $event) = @_;
	my $handled = 1; # assume the event was handled
	for ($event->{data}) {
		# order is determined by (supposed) frequency of use
		/^(?:kr|kl|[h\e\cH])$/io
							and $self->handleentry($event),				  last;
		/^l$/o				and $self->handlekeyell($event),			  last;
		/^k5$/o				and $self->handlerefresh($event),			  last;
		/^[cr]$/io			and $self->handlecopyrename($event),		  last;
		/^[yo]$/io			and $self->handlecommand($event),			  last;
		/^e$/io				and $self->handleedit($event),				  last;
		/^(?:d|del)$/io		and $self->handledelete($event),			  last;
		/^[ix]$/io			and $self->handleinclude($event),			  last;
		/^\r$/io			and $self->handleenter($event),				  last;
		/^s$/io				and $self->handleshow($event),				  last;
		/^kmous$/o			and $handled = $self->handlemousedown($event),last;
		/^k7$/o				and $self->handleswap($event),				  last;
		/^k10$/o			and $self->handlemultiple($event),			  last;
		/^m$/io				and $self->handlemore($event),				  last;
		/^p$/io				and $self->handleprint($event),				  last;
		/^L$/o				and $self->handlelink($event),				  last;
		/^n$/io				and $self->handlename($event),				  last;
		/^(k8| )$/o			and $self->handlemark($event),				  last;
		/^k11$/o			and $self->handlerestat($event),			  last;
		/^[\/f]$/io			and $self->handlefind($event),				  last;
		/^[<>]$/io			and $self->handlepan($event, MENU_SINGLE),	  last;
		/^(?:k3|\cL|\cR)$/o	and $self->handlefit($event),				  last;
		/^t$/io				and $self->handletime($event),				  last;
		/^a$/io				and $self->handlechmod($event),				  last;
		/^q$/io				and $handled = $self->handlequit($event),	  last;
		/^k6$/o				and $self->handlesinglesort($event),		  last;
		/^(?:k1|\?)$/o		and $self->handlehelp($event),				  last;
		/^k2$/o				and $self->handleprev($event),				  last;
		/^\.$/o				and $self->handledot($event),				  last;
		/^k9$/o				and $self->handlelayouts($event),			  last;
		/^k4$/o				and $self->handlecolor($event),				  last;
		/^\@$/o				and $self->handleperlcommand($event),		  last;
		/^u$/io				and $self->handlechown($event),				  last;
		/^v$/io				and $self->handleversion($event),			  last;
		/^z$/io				and $self->handlesize($event),				  last;
		/^g$/io				and $self->handletarget($event),			  last;
		/^k12$/o			and $self->handlemousemode($event),			  last;
		/^=$/o				and $self->handleident($event),				  last;
		/^\*$/o				and $self->handleradix($event),				  last;
		/^!$/o				and $self->handleclobber($event),			  last;
		/^"$/o				and $self->handlepathmode($event),			  last;
		/^w$/io				and $self->handleunwo($event),				  last;
		/^%$/o				and $self->handlewhiteout($event),			  last;
		$handled = 0;
		$self->{_screen}->flash();
	}
	return $handled;
}

=item handlepan(App::PFM::Event $event, int $menu_mode)

Handles the pan keys B<E<lt>> and B<E<gt>>.
This uses the B<MENU_> constants as defined in App::PFM::Screen::Frame.

=cut

sub handlepan {
	my ($self, $event, $mode) = @_;
	$self->{_screen}->frame->pan($event->{data}, $mode);
}

=item handleprev(App::PFM::Event $event)

Handles the B<previous> command (B<F2>).

=cut

sub handleprev {
	my ($self, $event) = @_;
	my $browser = $_pfm->browser;
	my $prevdir = $_pfm->state('S_PREV')->directory->path;
	my $chdirautocmd;
	if (chdir $prevdir) {
		# store current cursor position
		$_pfm->state->{_position}  = $event->{currentfile}{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# perform the swap
		$_pfm->swap_states('S_MAIN', 'S_PREV');
		# restore the cursor position
		$browser->baseindex(  $_pfm->state->{_baseindex});
		$browser->position_at($_pfm->state->{_position});
		# autocommand
		$chdirautocmd = $_pfm->config->{chdirautocmd};
		system("$chdirautocmd") if length($chdirautocmd);
		$self->{_screen}->set_deferred_refresh(R_SCREEN);
	} else {
		$self->{_screen}->set_deferred_refresh(R_MENU);
	}
}

=item handleswap(App::PFM::Event $event)

Swaps to an alternative directory (B<F7>).

=cut

sub handleswap {
	my ($self, $event) = @_;
	my $screen          = $self->{_screen};
	my $browser         = $_pfm->browser;
	my $swap_persistent = $_pfm->config->{swap_persistent};
	my $prompt          = 'Directory Pathname: ';
	my $prevstate       = $_pfm->state->clone();
	my $prevdir         = $prevstate->directory->path;
	my ($nextdir, $chdirautocmd, $success);
	if (ref $_pfm->state('S_SWAP')) {
		if ($swap_persistent) {
			# --------------------------------------------------
			# there is a persistent swap state
			# --------------------------------------------------
			# store current cursor position
			$_pfm->state->{_position}  = $event->{currentfile}{name};
			$_pfm->state->{_baseindex} = $browser->baseindex;
			# perform the swap
			$_pfm->swap_states('S_MAIN', 'S_SWAP');
			# continue below
		} else {
			# --------------------------------------------------
			# there is a non-persistent swap state
			# --------------------------------------------------
			# swap back if ok_to_remove_marks
			if (!$screen->ok_to_remove_marks()) {
				$screen->set_deferred_refresh(R_FRAME);
				return;
			}
			# perform the swap back
			$_pfm->state('S_MAIN', $_pfm->state('S_SWAP'));
			# destroy the swap state
			$_pfm->state('S_SWAP', 0);
			# continue below
		}
		# set refresh already (we may be swapping to '.')
		$screen->set_deferred_refresh(R_SCREEN);
		# --------------------------------------------------
		# common code for returning to a state
		# --------------------------------------------------
		# toggle swap mode flag
		$browser->swap_mode(!$browser->swap_mode);
		# destination
		$nextdir = $_pfm->state->directory->path;
		# go there using bare chdir() - the state is already up to date
		if ($success = chdir $nextdir) {
			if ($nextdir ne $prevdir) {
				# store the previous main state into S_PREV
				$_pfm->state('S_PREV', $prevstate);
			}
			# restore the cursor position
			$browser->baseindex(  $_pfm->state->{_baseindex});
			$browser->position_at($_pfm->state->{_position});
			if ($nextdir ne $prevdir) {
				# autocommand
				$chdirautocmd = $_pfm->config->{chdirautocmd};
				system("$chdirautocmd") if length($chdirautocmd);
			}
		} elsif (!$success) {
			# the state needs refreshing as we counted on being
			# able to chdir()
			$screen->at($screen->PATHLINE, 0)->clreol()
				->set_deferred_refresh(R_CHDIR)
				->display_error("$nextdir: $!");
			$_pfm->state->directory->set_dirty(D_ALL);
		}
	} else {
		# --------------------------------------------------
		# there is no swap state yet
		# --------------------------------------------------
		# ask and swap forward
		$screen->at(0,0)->clreol()->cooked_echo();
		$nextdir = $_pfm->history->input({
			history => H_PATH,
			prompt  => $prompt
		});
		$screen->raw_noecho()
			->set_deferred_refresh(R_FRAME);
		return if $nextdir eq '';
		# set refresh already (we may be swapping to '.')
		$screen->set_deferred_refresh(R_SCREEN);
		# store current cursor position
		$_pfm->state->{_position}  = $event->{currentfile}{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# store the main state
		$_pfm->state('S_SWAP', $_pfm->state->clone());
		# toggle swap mode flag
		$browser->swap_mode(!$browser->swap_mode);
		# fix destination
		$self->_expand_escapes(QUOTE_OFF, $nextdir, $event->{currentfile});
		# go there using the directory's chdir() (TODO $swapping flag behavior?)
		if ($_pfm->state->directory->chdir($nextdir, 0)) {
			# set the cursor position
			$browser->baseindex(0);
			$_pfm->state->{multiple_mode} = 0;
			$_pfm->state->sort_mode($_pfm->config->{defaultsortmode} || 'n');
			$screen->set_deferred_refresh(R_CHDIR);
		}
	}
}

=item handlerefresh(App::PFM::Event $event)

Handles the command to refresh the current directory (B<F5>).

=cut

sub handlerefresh {
	my ($self, $event) = @_;
	if ($self->{_screen}->ok_to_remove_marks()) {
		$self->{_screen}->set_deferred_refresh(R_SCREEN);
		$_pfm->state->directory->set_dirty(D_FILELIST);
	}
}

=item handlewhiteout(App::PFM::Event $event)

Toggles the filtering of whiteout files (key B<%>).

=cut

sub handlewhiteout {
	my ($self, $event) = @_;
	toggle($_pfm->state->{white_mode});
	# the directory object schedules a position_at when
	# $d->refresh() is called and the directory is dirty.
	$self->{_screen}->frame->update_headings();
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_FILTER);
}

=item handlemultiple(App::PFM::Event $event)

Toggles multiple mode (B<F10>).

=cut

sub handlemultiple {
	my ($self, $event) = @_;
	toggle($_pfm->state->{multiple_mode});
	$self->{_screen}->set_deferred_refresh(R_MENU);
}

=item handledot(App::PFM::Event $event)

Toggles the filtering of dotfiles (key B<.>).

=cut

sub handledot {
	my ($self, $event) = @_;
	toggle($_pfm->state->{dot_mode});
	# the directory object schedules a position_at when
	# $d->refresh() is called and the directory is dirty.
	$self->{_screen}->frame->update_headings();
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_FILTER);
}

=item handlecolor(App::PFM::Event $event)

Cycles through color modes (B<F4>).

=cut

sub handlecolor {
	my ($self, $event) = @_;
	$self->{_screen}->select_next_color();
}

=item handlemousemode(App::PFM::Event $event)

Handles turning mouse mode on or off (B<F12>).

=cut

sub handlemousemode {
	my ($self, $event) = @_;
	my $browser = $_pfm->browser;
	$browser->mouse_mode(!$browser->mouse_mode);
}

=item handlelayouts(App::PFM::Event $event)

Handles moving on to the next configured layout (B<F9>).

=cut

sub handlelayouts {
	my ($self, $event) = @_;
	$self->{_screen}->listing->select_next_layout();
}

=item handlefit(App::PFM::Event $event)

Recalculates the screen size and adjusts the layouts (B<F3>).

=cut

sub handlefit {
	my ($self, $event) = @_;
	$self->{_screen}->fit();
}

=item handleident(App::PFM::Event $event)

Calls the diskinfo class to cycle through showing
the username, hostname or both (key B<=>).

=cut

sub handleident {
	my ($self, $event) = @_;
	$self->{_screen}->diskinfo->select_next_ident();
}

=item handleclobber(App::PFM::Event $event)

Toggles between clobbering files automatically, or prompting
before overwrite (key B<!>.

=cut

sub handleclobber {
	my ($self, $event) = @_;
	$self->clobber_mode(!$self->{_clobber_mode});
	$self->{_screen}->set_deferred_refresh(R_FOOTER);
}

=item handlepathmode(App::PFM::Event $event)

Toggles between logical and physical path mode (key B<">).

=cut

sub handlepathmode {
	my ($self, $event) = @_;
	my $directory = $_pfm->state->directory;
	$directory->path_mode($directory->path_mode eq 'phys' ? 'log' : 'phys');
}

=item handleradix(App::PFM::Event $event)

Toggles between octal and hexadecimal radix (key B<*>), which is used for
showing nonprintable characters in the B<N>ame command.

=cut

sub handleradix {
	my ($self, $event) = @_;
	my $state = $_pfm->state;
	$state->{radix_mode} = ($state->{radix_mode} eq 'hex' ? 'oct' : 'hex');
	$self->{_screen}->set_deferred_refresh(R_FOOTER);
}

=item handlequit(App::PFM::Event $event)

Handles the B<q>uit and quick B<Q>uit commands.

=cut

sub handlequit {
	my ($self, $event) = @_;
	my $screen      = $self->{_screen};
	my $confirmquit = $_pfm->config->{confirmquit};
	return 'quit' if isno($confirmquit);
	return 'quit' if $event->{data} eq 'Q'; # quick quit
	return 'quit' if
		($confirmquit =~ /marked/i and !$screen->diskinfo->mark_info);
	$screen->show_frame({
			footer => FOOTER_NONE,
			prompt => 'Are you sure you want to quit [Y/N]? '
	});
	my $sure = $screen->getch();
	return 'quit' if ($sure =~ /y/i);
	$screen->set_deferred_refresh(R_MENU | R_FOOTER);
	return 0;
}

=item handleperlcommand(App::PFM::Event $event)

Handles executing a Perl command (key B<@>).

=cut

sub handleperlcommand {
	my ($self, $event) = @_;
	my $perlcmd;
	# for ease of use when debugging
	my $pfm            = $_pfm;
	my $config         = $_pfm->config;
	my $os             = $self->{_os};
	my $jobhandler     = $_pfm->jobhandler;
	my $commandhandler = $_pfm->commandhandler;
	my $history        = $_pfm->history;
	my $screen         = $self->{_screen};
	my $listing        = $screen->listing;
	my $frame          = $screen->frame;
	my $browser        = $_pfm->browser;
	my $currentfile    = $event->{currentfile};
	my $state          = $_pfm->state;
	my $directory      = $state->directory;
	# now do!
	$screen->listing->markcurrentline('@'); # disregard multiple_mode
	$screen->show_frame({
		footer => FOOTER_NONE,
		prompt => 'Enter Perl command:'
	});
	$screen->at($screen->PATHLINE,0)->clreol()->cooked_echo();
	$perlcmd = $_pfm->history->input({ history => H_PERLCMD });
	$screen->raw_noecho();
	eval $perlcmd;
	$screen->display_error($@) if $@;
	$screen->set_deferred_refresh(R_SCREEN);
}

=item handlehelp(App::PFM::Event $event)

Shows a help page with an overview of commands (B<F1>).

=cut

sub handlehelp {
	my ($self, $event) = @_;
	my $pages = 3;
	my $page  = 1;
	my ($key, $prompt);
	while ($page <= $pages) {
		$self->{_screen}->clrscr()->cooked_echo();
		$prompt = $self->_helppage($page);
		$key = $self->{_screen}->raw_noecho()->puts($prompt)->getch();
		if ($key =~ /(pgup|kl|ku|\cH|\c?|del)/o) {
			$page-- if $page > 1;
			redo;
		} elsif ($key =~ /(k1|\?)/o) {
			system qw(man pfm);
			last;
		}
	} continue {
		$page++;
	}
	$self->{_screen}->set_deferred_refresh(R_CLRSCR);
}

=item handleentry(App::PFM::Event $event)

Handles entering or leaving a directory (left arrow, right arrow,
B<ESC>, B<BS>, B<h>, B<l> (if on a directory), B<ENTER> (if on a
directory)).

=cut

sub handleentry {
	my ($self, $event) = @_;
	my ($tempptr, $nextdir, $success, $direction);
	my $currentdir = $_pfm->state->directory->path;
	if ($event->{data} =~ /^(?:kl|h|\e|\cH)$/io) {
		$nextdir   = '..';
		$direction = 'up';
	} else {
		$nextdir   = $event->{currentfile}{name};
		$direction = $nextdir eq '..' ? 'up' : 'down';
	}
	return if ($nextdir    eq '.');
	return if ($currentdir eq '/' && $direction eq 'up');
	return if !$self->{_screen}->ok_to_remove_marks();
	$success = $_pfm->state->directory->chdir($nextdir, 0, $direction);
	unless ($success) {
		$self->{_screen}->at(0,0)->clreol()->display_error($!);
		$self->{_screen}->set_deferred_refresh(R_MENU);
	}
	return $success;
}

=item handlemark(App::PFM::Event $event)

Handles marking (including or excluding) a file (key B<SPACE>
or B<F8>).

=cut

sub handlemark {
	my ($self, $event) = @_;
	my $currentfile  = $event->{currentfile};
	my $was_selected = $currentfile->{selected} eq M_MARK;
	if ($was_selected) {
		$_pfm->state->directory->exclude($currentfile, ' ');
	} else {
		$_pfm->state->directory->include($currentfile);
	}
	# redraw the line now, because we could be moving on
	# to the next file now (space command)
	$self->{_screen}->listing->highlight_off();
}

=item handlemarkall()

Handles marking (in-/excluding) all files.
The entries F<.> and F<..> are exempt from this action.

=cut

sub handlemarkall {
	my ($self) = @_;
	my $file;
	my $selected_nr_of = $_pfm->state->directory->selected_nr_of;
	my $showncontents  = $_pfm->state->directory->showncontents;
	if ($selected_nr_of->{d} + $selected_nr_of->{'-'} +
		$selected_nr_of->{s} + $selected_nr_of->{p} +
		$selected_nr_of->{c} + $selected_nr_of->{b} +
		$selected_nr_of->{l} + $selected_nr_of->{D} +
		$selected_nr_of->{w} + $selected_nr_of->{n} + 2 < @$showncontents)
	{
		foreach $file (@$showncontents) {
			if ($file->{selected} ne M_MARK and
				$file->{name} ne '.' and
				$file->{name} ne '..')
			{
				$_pfm->state->directory->include($file);
			}
		}
	} else {
		foreach $file (@$showncontents) {
			if ($file->{selected} eq M_MARK)
			{
				$_pfm->state->directory->exclude($file);
			}
		}
	}
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
}

=item handlemarkinverse()

Handles inverting all marks (B<I>nclude - B<I>nvert or eB<X>clude -
B<I>nvert). The entries F<.> and F<..> are exempt from this action.

=cut

sub handlemarkinverse {
	my ($self) = @_;
	my $file;
	my $showncontents  = $_pfm->state->directory->showncontents;
	foreach $file (@$showncontents) {
		if ($file->{name} ne '.' and
			$file->{name} ne '..')
		{
			if ($file->{selected} ne M_MARK) {
				$_pfm->state->directory->include($file);
			} else {
				$_pfm->state->directory->exclude($file);
			}
		}
	}
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
}

=item handlekeyell(App::PFM::Event $event)

Handles the lowercase B<l> key: enter the directory or create a link.

=cut

sub handlekeyell {
	my ($self, $event) = @_;
	# small l only
	if ($event->{currentfile}{type} eq 'd') {
		# this automagically passes the args to handleentry()
		goto &handleentry;
	} else {
		goto &handlelink;
	}
}

=item handlerestat(App::PFM::Event $event)

Re-executes a stat() on the current (or selected) files (B<F11>).

=cut

sub handlerestat {
	my ($self, $event) = @_;
	$_pfm->state->directory->apply(sub {}, $event);
}

=item handlelink(App::PFM::Event $event)

Creates a hard or symbolic link (B<L>ink as uppercase B<L>, or
lowercase B<l> if on a non-directory).

=cut

sub handlelink {
	my ($self, $event) = @_;
	my ($newname, $do_this, $testname, $headerlength, $absrel, $histpush);
	my @lncmd = $self->{_clobber_mode} ? qw(ln -f) : qw(ln);
	
	if ($_pfm->state->{multiple_mode}) {
		$self->{_screen}->set_deferred_refresh(R_FRAME | R_LISTING);
	} else {
		$self->{_screen}->set_deferred_refresh(R_FRAME);
		$self->{_screen}->listing->markcurrentline('L');
		$histpush = $event->{currentfile}{name};
	}
	
	$headerlength = $self->{_screen}->show_frame({
		menu => MENU_LNKTYPE,
	});
	$absrel = lc $self->{_screen}->at(0, $headerlength+1)->getch();
	return unless $absrel =~ /^[arh]$/;
	push @lncmd, '-s' unless $absrel eq 'h';
	
	$self->{_screen}->at(0,0)->clreol()->cooked_echo();
	my $prompt = 'Name of new '.
		( $absrel eq 'r' ? 'relative symbolic'
		: $absrel eq 'a' ? 'absolute symbolic' : 'hard') . ' link: ';
	
	chomp($newname = $_pfm->history->input({
		history       => H_PATH,
		prompt        => $prompt,
		history_input => $histpush,
	}));
	$self->{_screen}->raw_noecho();
	return if ($newname eq '');
	$newname = canonicalize_path($newname);
	# expand =[3456] at this point as a test, but not =[1278]
	$self->_expand_3456_escapes(QUOTE_OFF, ($testname = $newname));
	return if $self->_multi_to_single($testname);
	
	$do_this = sub {
		my $file = shift;
		my $newnameexpanded = $newname;
		my $state           = $_pfm->state;
		my $currentdir      = $state->directory->path;
		my ($simpletarget, $simplename, $targetstring, $mark);
		# $self is the commandhandler (closure!)
		$self->_expand_escapes($self->QUOTE_OFF, $newnameexpanded, $file);
		# keep this expanded version of the filename:
		# it will be used to determine if the newname is a subdirectory
		# of the current directory, and to make the cursor follow around.
		my $orignewnameexpanded = $newnameexpanded;
		# make sure $newname is a file (not a directory)
		if (-d $newnameexpanded) {
			$newnameexpanded .= '/'.$file->{name};
		}
		if ($absrel eq 'r') {
			if ($newnameexpanded =~ m!^/!) {
				# absolute: first eliminate identical pathname prefix
				($simpletarget, $simplename) = reducepaths(
					$currentdir.'/'.$file->{name}, $newnameexpanded);
				# now make absolute path relative
				$simpletarget =~ s!^/!!;
				$simpletarget =~ s![^/]+!..!g;
				$simpletarget = dirname($simpletarget);
				# and reverse it
				$targetstring = reversepath(
					$currentdir.'/'.$file->{name}, "$simpletarget/$simplename");
			} else {
				# relative: reverse path
				$targetstring = reversepath(
					$currentdir.'/'.$file->{name}, $newnameexpanded);
			}
		} else { # $absrel eq 'a' or 'h'
			# hand over an absolute path
			$targetstring = $currentdir.'/'.$file->{name};
		}
		if (system @lncmd, $targetstring, $newnameexpanded) {
			$self->{_screen}->neat_error('Linking failed');
		} elsif ($orignewnameexpanded !~ m!/!) {
			# let cursor follow around
			$_pfm->browser->position_at($orignewnameexpanded)
				unless $state->{multiple_mode};
			# add newname to the current directory listing.
			# TODO if newnameexpanded == swapdir, add there
			$mark = ($state->{multiple_mode}) ? M_NEWMARK : " ";
			$state->directory->addifabsent(
				entry   => $orignewnameexpanded,
				white   => '',
				mark    => $mark,
				refresh => TRUE);
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
}

=item handlesinglesort(App::PFM::Event $event)

Handles asking for user input and setting single-level sort mode.

=cut

sub handlesinglesort {
	my ($self, $event) = @_;
	$self->handlesort($event, FALSE);
}

=item handlesort(App::PFM::Event $event [, bool $multilevel ] )

Handles sorting the current directory (B<F6>).
The I<multilevel> argument indicates if the user must be offered
the possibility of entering a string of characters instead of
just a single one.

=cut

sub handlesort {
	my ($self, $event, $multilevel) = @_;
	my $screen    = $self->{_screen};
	my $printline = $screen->BASELINE;
	my $infocol   = $screen->diskinfo->infocol;
	my $frame     = $screen->frame;
	my %sortmodes = @{$_pfm->state->SORTMODES()};
	my ($i, $newmode, $menulength);
	$menulength = $frame->show({
		menu     => MENU_SORT,
		footer   => FOOTER_NONE,
		headings => HEADING_SORT,
	});
	$screen->diskinfo->clearcolumn();
	# we can't use foreach (keys %sortmodes) because we would lose ordering
	foreach (grep { ($i += 1) %= 2 } @{$_pfm->state->SORTMODES()}) {
		# keep keys, skip values
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		next if /[[:upper:]]/;
		$screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s', $_, $sortmodes{$_}));
	}
	if ($multilevel) {
		$screen->at(0,0)->clreol()->cooked_echo();
		chomp($newmode = $_pfm->history->input({
			history => H_MODE,
			prompt  => 'Sort by which modes? (uppercase=reverse): ',
		}));
		$screen->raw_noecho();
	} else {
		$newmode = $screen->at(0, $menulength)->getch();
	}
	$screen->set_deferred_refresh(R_SCREEN);
	$screen->diskinfo->clearcolumn();
	return if $newmode eq '';
	# find out if the resulting mode equals the newmode
	if ($newmode eq $_pfm->state->sort_mode($newmode)) {
		# if it has been set
		$_pfm->browser->position_at(
			$event->{currentfile}{name}, { force => 0, exact => 1 });
	}
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlecyclesort(App::PFM::Event $event)

Cycles through sort modes. Initiated by a mouse click on the 'Sort'
footer region.

=cut

sub handlecyclesort {
	my ($self, $event) = @_;
	# setup translations
	my @mode_to   = split(/,/, $_pfm->config->{sortcycle});
	my @mode_from = ($mode_to[-1], @mode_to);
	pop @mode_from;
	my %translations;
	@translations{@mode_from} = @mode_to;
	# do the translation
	my $newmode = $translations{$_pfm->state->sort_mode} || $mode_to[0];
	$_pfm->state->sort_mode($newmode);
	$_pfm->browser->position_at(
		$event->{currentfile}{name}, { force => 0, exact => 1 });
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlename(App::PFM::Event $event)

Shows all chacacters of the filename in a readable manner (B<N>ame).

=cut

sub handlename {
	my ($self, $event) = @_;
	my $numformat   = ${NUMFORMATS()}{$_pfm->state->{radix_mode}};
	my $browser     = $_pfm->browser;
	my $screen      = $self->{_screen};
	my $workfile    = $event->{currentfile}->clone();
	my $screenline  = $browser->currentline + $screen->BASELINE;
	my $filenamecol = $screen->listing->filenamecol;
	my $trspace     = $_pfm->config->{trspace};
	my ($line, $linecolor);
	$screen->listing->markcurrentline('N'); # disregard multiple_mode
	for ($workfile->{name}, $workfile->{target}) {
		s/\\/\\\\/;
		s{([${trspace}\177[:cntrl:]]|[^[:ascii:]])}
		 {'\\' . sprintf($numformat, unpack('C', $1))}eg;
	}
	$line = $workfile->{name} . $workfile->filetypeflag() .
			(length($workfile->{target}) ? ' -> ' . $workfile->{target} : '');
	$linecolor =
		$_pfm->config->{framecolors}{$screen->color_mode}{highlight};
	
	$screen->at($screenline, $filenamecol)
		->putcolored($linecolor, $line, " \cH");
	$screen->listing->applycolor(
		$screenline, $screen->listing->FILENAME_LONG, $workfile);
	if ($screen->noecho()->getch() eq '*') {
		$self->handleradix();
		$screen->echo()->at($screenline, $filenamecol)
			->puts(' ' x length $line)
			->frame->show_footer(FOOTER_SINGLE);
		goto &handlename;
	}
	if ($filenamecol < $screen->diskinfo->infocol &&
		$filenamecol + length($line) >= $screen->diskinfo->infocol or
		$filenamecol + length($line) >= $screen->screenwidth)
	{
		$screen->set_deferred_refresh(R_CLRSCR);
	}
}

=item handlefind(App::PFM::Event $event)

Prompts for a filename to find, then positions the cursor at that file.
B<Find> or key B</>.

=item handlefind_incremental()

Prompts for a filename to find, and positions the cursor while the name
is typed (incremental find). Only applicable if the current sort_mode
is by name (ascending or descending).
B<Find> or key B</>.

=cut

sub handlefind {
	my ($self, $event) = @_;
	if (lc($_pfm->state->sort_mode) eq 'n') {
		goto &handlefind_incremental;
	}
	my ($findme, $file);
	$self->{_screen}->clear_footer()->at(0,0)->clreol()->cooked_echo();
	($findme = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'File to find: ',
	})) =~ s/\/$//;
	if ($findme =~ /\//) { $findme = basename($findme) };
	$self->{_screen}->raw_noecho()->set_deferred_refresh(R_MENU);
	return if $findme eq '';
	FINDENTRY:
	foreach $file (sort by_name @{$_pfm->state->directory->showncontents}) {
		if ($findme le $file->{name}) {
			$_pfm->browser->position_at($file->{name});
			last FINDENTRY;
		}
	}
	$self->{_screen}->set_deferred_refresh(R_LISTING);
}

sub handlefind_incremental {
	my ($self) = @_;
	my ($findme, $key, $screenline);
	my $screen = $self->{_screen};
	my $prompt = 'File to find: ';
	my $cursorjumptime = .5;
	my $cursorcol = $screen->listing->cursorcol;
	$screen->clear_footer();
	FINDINCENTRY:
	while (1) {
		$screen
			->listing->highlight_on()
			->at(0,0)->clreol()->putmessage($prompt)
			->puts($findme);
		if ($cursorjumptime) {
			$screenline = $_pfm->browser->currentline + $screen->BASELINE;
			while (!$screen->key_pressed($cursorjumptime)) {
				$screen->at($screenline, $cursorcol);
				last if ($screen->key_pressed($cursorjumptime));
				$screen->at(0, length($prompt) + length $findme);
			}
		}
		$key = $screen->getch();
		$screen->listing->highlight_off();
		if ($key eq "\cM" or $key eq "\e") {
			last FINDINCENTRY;
		} elsif ($key eq "\cH" or $key eq 'del' or $key eq "\x7F") {
			chop($findme);
		} elsif ($key eq "\cY" or $key eq "\cE") {
			$findme =~ s/(.*\s+|^)(\S+\s*)$/$1/;
#		} elsif ($key eq "\cW") {
#			$findme =~ s/(.*\s+|^)(\S+\s*)$/$1/;
		} elsif ($key eq "\cU") {
			$findme = '';
		} else {
			$findme .= $key;
		}
		$_pfm->browser->position_cursor_fuzzy($findme);
		$screen->listing->show();
	}
	$screen->set_deferred_refresh(R_MENU);
}

=item handleedit(App::PFM::Event $event)

Starts the editor for editing the current fileZ<>(s) (B<E>dit command).

=cut

sub handleedit {
	my ($self, $event) = @_;
	my $do_this;
	$self->{_screen}->alternate_off()->clrscr()->at(0,0)->cooked_echo();
	$do_this = sub {
		my $file = shift;
		system $_pfm->config->{editor}." \Q$file->{name}\E"
			and $self->{_screen}->display_error('Editor failed');
	};
	$_pfm->state->directory->apply($do_this, $event);
	$self->{_screen}->alternate_on() if $_pfm->config->{altscreen_mode};
	$self->{_screen}->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handlechown(App::PFM::Event $event)

Handles changing the owner of a file (B<U>ser command).

=cut

sub handlechown {
	my ($self, $event) = @_;
	my ($newuid, $do_this);
	if ($_pfm->state->{multiple_mode}) {
		$self->{_screen}->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$self->{_screen}->set_deferred_refresh(R_MENU | R_PATHINFO);
		$self->{_screen}->listing->markcurrentline('U');
	}
	$self->{_screen}->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newuid = $_pfm->history->input({
		history => H_MODE,
		prompt  => 'New [user][:group] ',
	}));
	$self->{_screen}->raw_noecho();
	return if ($newuid eq '');
	$do_this = sub {
		my $file = shift;
		if (system('chown', $newuid, $file->{name})) {
			$self->{_screen}->neat_error('Change owner failed');
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
	# re-sort
	if ($_pfm->state->sort_mode =~ /[ug]/i and
		$_pfm->config->{autosort})
	{
		$self->{_screen}->set_deferred_refresh(R_LISTING);
		# 2.06.4: sortcontents() doesn't sort @showncontents.
		# therefore, apply the filter again as well.
		$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
		# TODO fire 'save_cursor_position'
		$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
	}
}

=item handlechmod(App::PFM::Event $event)

Handles changing the mode (permission bits) of a file (B<A>ttribute command).

=cut

sub handlechmod {
	my ($self, $event) = @_;
	my ($newmode, $do_this);
	my $screen = $self->{_screen};
	if ($_pfm->state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$screen->listing->markcurrentline('A');
	}
	$screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newmode = $_pfm->history->input({
		history => H_MODE,
		prompt  => 'New mode [ugoa][-=+][rwxslt] or octal: ',
	}));
	$screen->raw_noecho();
	return if ($newmode eq '');
	if ($newmode =~ s/^\s*(\d+)\s*$/oct($1)/e) {
		$do_this = sub {
			my $file = shift;
			unless (chmod $newmode, $file->{name}) {
				$screen->neat_error($!);
			}
		};
	} else {
		$do_this = sub {
			my $file = shift;
			if (system 'chmod', $newmode, $file->{name}) {
				$screen->neat_error('Change mode failed');
			}
		};
	}
	$_pfm->state->directory->apply($do_this, $event);
}

=item handletime(App::PFM::Event $event)

Handles changing the timestamp of a file (B<T>ime command).

=cut

sub handletime {
	my ($self, $event) = @_;
	my ($newtime, $do_this, @cmdopts);
	my $screen = $self->{_screen};
	if ($_pfm->state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$screen->listing->markcurrentline('T');
	}
	$screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	$newtime = $_pfm->history->input({
		history       => H_TIME,
		prompt        => 'Timestamp [[CC]YY-]MM-DD hh:mm[.ss]: ',
		history_input => strftime ("%Y-%m-%d %H:%M.%S", localtime time),
	});
	$screen->raw_noecho();
	return if ($newtime eq '');
	if ($newtime eq '.') {
		$newtime = time;
	} else {
		# translate from local timezone to UTC
		$newtime = mktime gmtime touch2time($newtime);
		return unless defined $newtime;
	}
	$do_this = sub {
		my $file = shift;
		if (!utime $newtime, $newtime, $file->{name}) {
			$screen->neat_error('Set timestamp failed');
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
	# re-sort
	if ($_pfm->state->sort_mode =~ /[da]/i and
		$_pfm->config->{autosort})
	{
		$screen->set_deferred_refresh(R_LISTING);
		# 2.06.4: sortcontents() doesn't sort @showncontents.
		# therefore, apply the filter again as well.
		$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
		# TODO fire 'save_cursor_position'
		$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
	}
}

=item handleshow(App::PFM::Event $event)

Handles displaying the contents of a file (B<S>how command).

=cut

sub handleshow {
	my ($self, $event) = @_;
	my ($do_this);
	if ($self->_followmode($event->{currentfile}) =~ /^d/) {
		goto &handleentry;
	}
	$self->{_screen}->clrscr()->at(0,0)->cooked_echo();
	$do_this = sub {
		my $file = shift;
		$self->{_screen}->puts($file->{name} . "\n")
			->alternate_off();
		system $_pfm->config->{pager}." \Q$file->{name}\E"
			and $self->{_screen}->display_error("Pager failed\n");
		$self->{_screen}->alternate_on() if $_pfm->config->{altscreen_mode};
	};
	$_pfm->state->directory->apply($do_this, $event);
	$self->{_screen}->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handleunwo(App::PFM::Event $event)

Handles removing a whiteout file (unB<W>hiteout command).

=cut

sub handleunwo {
	my ($self, $event) = @_;
	my ($do_this);
	my $screen = $self->{_screen};
	my $nowhiteouterror = 'Current file is not a whiteout';
	if ($_pfm->state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_MENU | R_LISTING);
	} else {
		$screen->set_deferred_refresh(R_MENU);
		$screen->listing->markcurrentline('W');
	}
	if (!$_pfm->state->{multiple_mode} and
		$event->{currentfile}{type} ne 'w')
	{
		$screen->at(0,0)->clreol()->display_error($nowhiteouterror);
		return;
	}
	$screen->at($screen->PATHLINE,0);
	$do_this = sub {
		my $file = shift;
		if ($file->{type} eq 'w') {
			if ($self->{_os}->unwo($file->{name})) {
				$screen->neat_error('Whiteout removal failed');
			}
		} else {
			$screen->neat_error($nowhiteouterror);
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
}

=item handleversion(App::PFM::Event $event)

Checks if the current directory is under version control,
and starts a job for the file if so (B<V>ersion command).

=cut

sub handleversion {
	my ($self, $event) = @_;
	if ($_pfm->state->{multiple_mode}) {
		$_pfm->state->directory->apply(sub {}, $event);
		$_pfm->state->directory->checkrcsapplicable();
		$self->{_screen}->set_deferred_refresh(R_LISTING | R_MENU);
	} else {
		$_pfm->state->directory->checkrcsapplicable(
			$event->{currentfile}{name});
	}
}

=item handleinclude(App::PFM::Event $event)

Handles including (marking) and excluding (unmarking) files
(B<I>nclude and eB<X>clude commands).

=cut

sub handleinclude { # include/exclude flag (from keypress)
	my ($self, $event) = @_;
	my $screen       = $self->{_screen};
	my $directory    = $_pfm->state->directory;
	my $printline    = $screen->BASELINE;
	my $infocol      = $screen->diskinfo->infocol;
	my $exin         = $event->{data};
	my %inc_criteria = @{INC_CRITERIA()};
	my ($criterion, $menulength, $key, $wildfilename, $entry, $i,
		$boundarytime, $boundarysize);
	$exin = lc $exin;
	$screen->diskinfo->clearcolumn();
	# we can't use foreach (keys %mark_criteria) because we would lose ordering
	foreach (grep { ($i += 1) %= 2 } @{INC_CRITERIA()}) { # keep keys, skip values
		last if ($printline > $screen->BASELINE + $screen->screenheight);
		$screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s', $_, $inc_criteria{$_}));
	}
	my $menu_mode = $exin eq 'x' ? MENU_EXCLUDE : MENU_INCLUDE;
	$menulength = $screen
		->set_deferred_refresh(R_FRAME | R_PATHINFO | R_DISKINFO)
		->show_frame({
			menu     => $menu_mode,
			footer   => FOOTER_NONE,
			headings => HEADING_CRITERIA
		});
	$key = lc $screen->at(0, $menulength+1)->getch();
	if      ($key eq 'o') { # oldmarks
		$criterion = sub { my $file = shift; $file->{selected} eq M_OLDMARK };
	} elsif ($key eq 'n') { # newmarks
		$criterion = sub { my $file = shift; $file->{selected} eq M_NEWMARK };
	} elsif ($key eq 'e') { # every
		$criterion = sub { my $file = shift; $file->{name} !~ /^\.\.?$/o };
	} elsif ($key eq 'u') { # user only
		$criterion = sub { my $file = shift; $file->{uid} eq $ENV{USER} };
	} elsif ($key eq '.') { # dotfiles
		$criterion = sub { my $file = shift; $file->{name} =~ /^\./o };
	} elsif ($key =~ /^[gs]$/) { # greater/smaller
		if ($boundarysize = $self->_promptforboundarysize($key)) {
			if ($key eq 'g') {
				$criterion = sub {
					my $file = shift;
					$file->{size} >= $boundarysize and
					$file->{name} !~ /^\.\.?$/o;
				};
			} else {
				$criterion = sub {
					my $file = shift;
					$file->{size} <= $boundarysize and
					$file->{name} !~ /^\.\.?$/o;
				};
			}
		} # if $boundarysize
	} elsif ($key =~ /^[ab]$/) { # after/before mtime
		if ($boundarytime = $self->_promptforboundarytime($key)) {
			# this was the behavior of PFM.COM, IIRC
			$wildfilename = $self->_promptforwildfilename();
			if ($key eq 'a') {
				$criterion = sub {
					my $file = shift;
					$file->{name} =~ /$wildfilename/ and
					$file->{mtime} > $boundarytime;
				};
			} else {
				$criterion = sub {
					my $file = shift;
					$file->{name} =~ /$wildfilename/ and
					$file->{mtime} < $boundarytime;
				};
			}
		} # if $boundarytime
	} elsif ($key eq 'f') { # regular files
		$wildfilename = $self->_promptforwildfilename();
		# it seems that ("a" =~ //) == false, that comes in handy
		$criterion = sub {
			my $file = shift;
			$file->{name} =~ /$wildfilename/ and
			$file->{type} eq '-';
		};
	} elsif ($key eq 'i') { # invert selection
		$self->handlemarkinverse();
		return;
	}
	if ($criterion) {
		foreach $entry (@{$directory->showncontents}) {
			if ($criterion->($entry)) {
				if ($exin eq 'x') {
					$directory->exclude($entry);
				} else {
					$directory->include($entry);
				}
				$screen->set_deferred_refresh(R_SCREEN);
			}
		}
	}
}

=item handlesize(App::PFM::Event $event)

Handles reporting the size of a file, or of a directory and
subdirectories (siB<Z>e command).

=cut

sub handlesize {
	my ($self, $event) = @_;
	my ($do_this);
	my $screen        = $self->{_screen};
	my $filerecordcol = $screen->listing->filerecordcol;
	if ($_pfm->state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_SCREEN);
	} else {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$screen->listing->markcurrentline('Z');
	}
	$do_this = sub {
		my $file = shift;
		my ($recursivesize, $command, $tempfile, $res);
		$recursivesize = $self->{_os}->du($file->{name});
		$recursivesize =~ s/^\D*(\d+).*/$1/;
		chomp $recursivesize;
		# if a CHLD signal handler is installed, $? is not always reliable.
		if ($?) {
			$screen->at(0,0)->clreol()
				->putmessage('Could not read all directories')
				->set_deferred_refresh(R_SCREEN);
			$recursivesize ||= 0;
		}
		@{$file}{qw(grand grand_num grand_power)} =
			($recursivesize, fit2limit(
				$recursivesize, $screen->listing->maxgrandtotallength));
		if (join('', @{$screen->listing->layoutfields}) !~ /grand/ and
			!$_pfm->state->{multiple_mode})
		{
			my $screenline = $_pfm->browser->currentline + $screen->BASELINE;
			# use filesize field of a cloned object.
			$tempfile = $file->clone();
			@{$tempfile}{qw(size size_num size_power)} =
				($recursivesize, fit2limit(
					$recursivesize, $screen->listing->maxfilesizelength));
			$screen->at($screenline, $filerecordcol)
				->puts($screen->listing->fileline($tempfile))
				->listing->markcurrentline('Z')
				->listing->applycolor($screenline,
					$screen->listing->FILENAME_SHORT, $tempfile);
			$screen->getch();
		}
		return $file;
	};
	$event->{lunchbox}{applyflags} = 'norestat';
	$_pfm->state->directory->apply($do_this, $event);
}

=item handletarget(App::PFM::Event $event)

Changes the target of a symbolic link (tarB<G>et command).

=cut

sub handletarget {
	my ($self, $event) = @_;
	my ($newtarget, $do_this);
	my $screen = $self->{_screen};
	if ($_pfm->state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$screen->listing->markcurrentline('G');
	}
	my $nosymlinkerror = 'Current file is not a symbolic link';
	if ($event->{currentfile}{type} ne 'l' and
		!$_pfm->state->{multiple_mode})
	{
		$screen->at(0,0)->clreol()->display_error($nosymlinkerror);
		return;
	}
	$screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newtarget = $_pfm->history->input({
		history       => H_PATH,
		prompt        => 'New symlink target: ',
		history_input => $event->{currentfile}{target},
	}));
	$screen->raw_noecho();
	return if ($newtarget eq '');
	$do_this = sub {
		my $file = shift;
		my ($newtargetexpanded, $oldtargetok);
		if ($file->{type} ne 'l') {
			$screen->at(0,0)->clreol()->display_error($nosymlinkerror);
		} else {
			# $self is the commandhandler (closure!)
			$self->_expand_escapes(
				$self->QUOTE_OFF, ($newtargetexpanded = $newtarget), $file);
			$oldtargetok = 1;
			if (-d $file->{name}) {
				# if it points to a dir, the symlink must be removed first
				# next line is an intentional assignment
				unless ($oldtargetok = unlink $file->{name}) {
					$screen->neat_error($!);
				}
			}
			if ($oldtargetok and
				system qw(ln -sf), $newtargetexpanded, $file->{name})
			{
				$screen->neat_error('Replace symlink failed');
			}
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
}

=item handlecommand(App::PFM::Event $event)

Executes a shell command (cB<O>mmand and B<Y>our-command).

=cut

sub handlecommand { # Y or O
	my ($self, $event) = @_;
	my $screen     = $self->{_screen};
	my $printline  = $screen->BASELINE;
	my $infocol    = $screen->diskinfo->infocol;
	my $infolength = $screen->diskinfo->infolength;
	my $e          = $_pfm->config->{e};
	my $key        = uc $event->{data};
	my ($command, $do_this, $prompt, $printstr, $newdir);
	unless ($_pfm->state->{multiple_mode}) {
		$screen->listing->markcurrentline($key);
	}
	$screen->diskinfo->clearcolumn();
	if ($key eq 'Y') { # Your command
		$prompt = 'Enter one of the highlighted characters below: ';
		foreach (sort alphabetically $_pfm->config->your_commands) {
			last if ($printline > $screen->BASELINE + $screen->screenheight);
			$printstr = $_pfm->config->pfmrc()->{$_};
			$printstr =~ s/\e/^[/g; # in case real escapes are used
			$screen->at($printline++, $infocol)
				->puts(sprintf('%1s %s',
						substr($_,5,1),
						substr($printstr,0,$infolength-2)));
		}
		$screen->show_frame({
			headings => HEADING_YCOMMAND,
			footer   => FOOTER_NONE,
			prompt   => $prompt,
		});
		$key = $screen->getch();
		$screen->diskinfo->clearcolumn()
			->set_deferred_refresh(R_DISKINFO | R_FRAME);
		# next line contains an assignment on purpose
		return unless $command = $_pfm->config->pfmrc()->{"your[$key]"};
		$screen->cooked_echo();
	} else { # cOmmand
		$prompt =
			"Enter Unix command ($e"."[1-8] or $e"."[epv] escapes see below):";
		foreach (sort escape_midway keys %{CMDESCAPES()}, $e) {
			if ($printline <= $screen->BASELINE + $screen->screenheight) {
				$screen->at($printline++, $infocol)
					->puts(sprintf(' %1s%1s %s', $e, $_,
							${CMDESCAPES()}{$_} || "literal $e"));
			}
		}
		$screen->show_frame({
			menu     => MENU_NONE,
			footer   => FOOTER_NONE,
			headings => HEADING_ESCAPE,
		});
		$screen->set_deferred_refresh(R_DISKINFO);
		$screen->at(0,0)->clreol()->putmessage($prompt)
			->at($screen->PATHLINE,0)->clreol()
			->cooked_echo();
		$command = $_pfm->history->input({
			history => H_COMMAND,
			prompt  => ''
		});
		$screen->diskinfo->clearcolumn();
	}
	# chdir special case
	if ($command =~ /^\s*cd\s(.*)$/) {
		$newdir = $1;
		$self->_expand_escapes(QUOTE_OFF, $newdir, $event->{currentfile});
		$screen->raw_noecho();
		if (!$screen->ok_to_remove_marks()) {
			$screen->set_deferred_refresh(R_MENU); # R_SCREEN?
			return;
		} elsif (!$_pfm->state->directory->chdir($newdir)) {
			$screen->at(2,0)->display_error("$newdir: $!")
				->set_deferred_refresh(R_SCREEN);
			return;
		}
		$screen->set_deferred_refresh(R_CHDIR);
		return;
	}
	# general case: command (either Y or O) is known here
	if ($command !~ /\S/) {
		$screen->raw_noecho()->set_deferred_refresh(R_MENU | R_PATHINFO);
		return
	}
	$screen->alternate_off()->clrscr()->at(0,0);
	$do_this = sub {
		my $file = shift;
		my $do_command = $command;
		# $self is the commandhandler (closure!)
		$self->_expand_escapes($self->QUOTE_ON, $do_command, $file);
		$screen->puts("\n$do_command\n");
		system $do_command
			and $screen->display_error("External command failed\n");
	};
	$event->{lunchbox}{applyflags} = 'nofeedback';
	$_pfm->state->directory->apply($do_this, $event);
	$screen->pressanykey();
	$screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handleprint(App::PFM::Event $event)

Executes a print command (B<P>print).

=cut

sub handleprint {
	my ($self, $event) = @_;
	my ($do_this, $command);
	my $screen   = $self->{_screen};
	my $printcmd = $_pfm->config->{printcmd};
	if (!$_pfm->state->{multiple_mode}) {
		$screen->listing->markcurrentline('P');
	}
	$screen->show_frame({
		footer => FOOTER_NONE,
		prompt => 'Enter print command: ',
	});
	$screen->at($screen->PATHLINE, 0)->clreol()
		->cooked_echo();
	$command = $_pfm->history->input({
		history       => H_COMMAND,
		prompt        => '',
		default_input => $printcmd,
		pushfilter    => $printcmd,
	});
	$screen->raw_noecho();
	if ($command eq '') {
		$screen->set_deferred_refresh(R_FRAME | R_DISKINFO | R_PATHINFO);
		return;
	}
	#$screen->alternate_off()->clrscr()->at(0,0);
	$do_this = sub {
		my $file = shift;
		my $do_command = $command;
		$self->_expand_escapes($self->QUOTE_ON, $do_command, $file);
		$screen->puts("\n$do_command\n");
		system $do_command
			and $screen->display_error("Print command failed\n");
	};
	# we could supply 'O' in the next line to treat it like a real cOmmand
	$_pfm->state->directory->apply($do_this, $event);
	#$screen->pressanykey();
	#$screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$screen->set_deferred_refresh(R_SCREEN);
	return;
}

=item handledelete(App::PFM::Event $event)

Handles deleting files (B<D>elete command).

=cut

sub handledelete {
	my ($self, $event) = @_;
	my ($do_this, $sure, $oldpos);
	my $screen     = $self->{_screen};
	my $browser    = $_pfm->browser;
	my $directory  = $_pfm->state->directory;
	unless ($_pfm->state->{multiple_mode}) {
		$screen->listing->markcurrentline('D');
	}
	if ($_pfm->state->{multiple_mode} or $event->{currentfile}{nlink}) {
		$screen->set_deferred_refresh(R_MENU | R_FOOTER)
			->show_frame({
				footer => FOOTER_NONE,
				prompt => 'Are you sure you want to delete [Y/N]? ',
			});
		$sure = $screen->getch();
		return if $sure !~ /y/i;
	}
	$screen->at($screen->PATHLINE, 0)
		->set_deferred_refresh(R_SCREEN);
#	$_pfm->state->directory->set_dirty(D_FILELIST);
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
	$do_this = sub {
		my $file = shift;
		my ($msg, $success);
		if ($file->{name} eq '.') {
			# don't allow people to delete '.'; normally, this could be allowed
			# if it is empty, but if that leaves the parent directory empty,
			# then it can also be removed, which causes a fatal pfm error.
			$msg = 'Deleting current directory not allowed';
			$success = 0;
		} elsif ($file->{nlink} == 0 and $file->{type} ne 'w') {
			# remove 'lost files' immediately, no confirmation needed
			$success = 1;
		} elsif ($file->{type} eq 'd') {
			if (testdirempty($file->{name})) {
				$success = rmdir $file->{name};
			} else {
				$screen->at(0,0)->clreol()->putmessage(
					'Recursively delete a non-empty directory ',
					'[Affirmative/Negative]? ');
				$sure = lc $screen->getch();
				$screen->at(0,0);
				if ($sure eq 'a') {
					$success = !system('rm', '-rf', $file->{name});
				} else {
					$msg = 'Deletion cancelled. Directory not empty';
					$success = 0;
				}
				$screen->clreol();
			}
		} else {
			$success = unlink $file->{name};
		}
		if (!$success) {
			$screen->display_error($msg || $!);
		}
		return $success ? 'deleted' : '';
	};
	$oldpos = $event->{currentfile}{name};
	$event->{lunchbox}{applyflags} = 'delete';
	$directory->apply($do_this, $event);
	if ($_pfm->state->{multiple_mode}) {
		# %nameindexmap may be completely invalid at this point. use dirlookup()
		if (dirlookup($oldpos, @{$directory->showncontents}) > 0) {
			$browser->position_at($oldpos);
		}
	} elsif ($browser->position_at eq '') {
		$_pfm->browser->validate_position();
	}
	return;
}

=item handlecopyrename(App::PFM::Event $event)

Handles copying and renaming files (B<C>opy and B<R>ename).

=cut

sub handlecopyrename {
	my ($self, $event) = @_;
	my $screen  = $self->{_screen};
	my $key     = uc $event->{data};
	my @command = (($key eq 'C' ? qw(cp -r) : 'mv'),
					($self->{_clobber_mode} ? '-f' : '-i'));
	if ($_pfm->config->{copyoptions}) {
		push @command, $_pfm->config->{copyoptions};
	}
	my $prompt = $key eq 'C' ? 'Destination: ' : 'New name: ';
	my ($testname, $newname, $newnameexpanded, $do_this, $sure, $mark);
	my $browser = $_pfm->browser;
	my $state   = $_pfm->state;
	if ($state->{multiple_mode}) {
		$screen->set_deferred_refresh(R_MENU | R_FOOTER | R_LISTING);
	} else {
		$screen->set_deferred_refresh(R_MENU | R_FOOTER);
		$screen->listing->markcurrentline($key);
	}
	$screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	my $history_input =
		$state->{multiple_mode} ? undef : $event->{currentfile}{name};
	$newname = $_pfm->history->input({
		history       => H_PATH,
		prompt        => $prompt,
		history_input => $history_input,
	});
	$screen->raw_noecho();
	return if ($newname eq '');
	# expand =[3456] at this point as a test, but not =[1278]
	$self->_expand_3456_escapes(QUOTE_OFF, ($testname = $newname));
	return if $self->_multi_to_single($testname);
	$screen->at(1,0)->clreol() unless $self->{_clobber_mode};
	$do_this = sub {
		my $file = shift;
		my $findindex;
		# move this outsde of do_this
#		if ($key eq 'C' and $file->{type} =~ /[ld]/ ) {
#			# AIX: cp -r follows symlink
#			# Linux: cp -r copies symlink
#			$screen->at(0,0)->clreol();
#				->putmessage('Copy symlinks to symlinks [Copy/Follow]? ');
#			$sure = lc $screen->getch();
#			$screen->at(0,0);
#			if ($sure eq 'c') {
#			} else {
#			}
#			$screen->clreol();
#		} elsif
		# $self is the commandhandler (closure!)
		$self->_expand_escapes(
			QUOTE_OFF, ($newnameexpanded = $newname), $file);
		if (system @command, $file->{name}, $newnameexpanded) {
			$screen->neat_error($key eq 'C' ? 'Copy failed' : 'Rename failed');
		} elsif ($newnameexpanded !~ m!/!) {
			# let cursor follow around
			$browser->position_at($newnameexpanded)
				unless $state->{multiple_mode};
			# add newname to the current directory listing.
			# TODO if newnameexpanded == swapdir, add there
			$mark = ($state->{multiple_mode}) ? M_NEWMARK : " ";
			$state->directory->addifabsent(
				entry   => $newnameexpanded,
				white   => '',
				mark    => $mark,
				refresh => TRUE);
		}
	};
	$screen->cooked_echo() unless $self->{_clobber_mode};
	$state->directory->apply($do_this, $event);
	# if ! $clobber_mode, we might have gotten an 'Overwrite?' question
	unless ($self->{_clobber_mode}) {
		$screen->set_deferred_refresh(R_SCREEN);
		$screen->raw_noecho();
	}
	return;
}

=item handleopenwindow(App::PFM::Event $event)

Opens a new terminal window running pfm.

=cut

sub handleopenwindow {
	my ($self, $event) = @_;
	my $file = $event->{currentfile};
	my $nodirerror = 'Current file is not a directory';
	if ($file->{type} ne 'd')
	{
		$self->{_screen}->at(0,0)->clreol()->display_error($nodirerror);
		return;
	}
	my $windowcmd = $_pfm->config->{windowcmd};
	if ($_pfm->config->{windowtype} eq 'pfm') {
		# windowtype = pfm
		if (ref $_pfm->state('S_SWAP')) {
			system("$windowcmd 'pfm \Q$file->{name}\E -s " .
				quotemeta($_pfm->state('S_SWAP')->{path}) . "' &");
		} else {
			system("$windowcmd 'pfm \Q$file->{name}\E' &");
		}
	} else {
		# windowtype = standalone
		system("$windowcmd \Q$file->{name}\E &");
	}
}

=item handlemousedown(App::PFM::Event $event)

Handles mouse clicks. Note that the mouse wheel has already been handled
by the browser. This handles only the first three mouse buttons.

=cut

sub handlemousedown {
	my ($self, $event) = @_;
	my ($on_name, $clicked_file);
	my $screen   = $self->{_screen};
	my $browser  = $_pfm->browser;
	my $listing  = $screen->listing;
	my $mbutton  = $event->{mousebutton};
	my $mousecol = $event->{mousecol};
	my $mouserow = $event->{mouserow};
	my $propagated_event = new App::PFM::Event({
		name   => 'after_receive_non_motion_input',
		type   => 'key',
		origin => $self,
	});
	# button ---------------- location clicked ------------------------
	#       pathline  menu/footer  heading   fileline  filename dirname
	# 1     chdir()  (pfm command) sort      F8        Show     Show
	# 2     cOmmand  (pfm command) sort rev  Show      ENTER    new win
	# 3     cOmmand  (pfm command) sort rev  Show      ENTER    new win
	# -----------------------------------------------------------------
	if ($mouserow == $screen->PATHLINE) {
		# path line
		if ($mbutton == BUTTON_LEFT) {
			$self->handlemousepathjump($event);
		} else {
			$propagated_event->{data} = 'o';
			$self->handlecommand($propagated_event);
		}
	} elsif ($mouserow == $screen->HEADINGLINE) {
		# headings
		$self->handlemouseheadingsort($event);
	} elsif ($mouserow == 0) {
		# menu
		# return the return value as this could be 'quit'
		return $self->handlemousemenucommand($event);
	} elsif ($mouserow > $screen->screenheight + $screen->BASELINE) {
		# footer
		$self->handlemousefootercommand($event);
	} elsif (($mousecol < $listing->filerecordcol)
		or	($mousecol >= $screen->diskinfo->infocol
		and	$screen->diskinfo->infocol > $listing->filerecordcol))
	{
		# diskinfo
		$self->handleident($event)
			if $mouserow == $screen->diskinfo->LINE_USERINFO;
	} elsif (defined ${$_pfm->state->directory->showncontents}[
		$mouserow - $screen->BASELINE + $browser->baseindex])
	{
		# clicked on an existing file
		$clicked_file = $event->{mouseitem};
		$propagated_event->{currentfile} = $clicked_file;
		$on_name = (
			$mousecol >= $listing->filenamecol and
			$mousecol <= $listing->filenamecol + $listing->maxfilenamelength);
		if ($on_name and $mbutton != BUTTON_LEFT) {
			if ($clicked_file->{type} eq 'd') {
				# keep the mouse event here, since there is no keyboard
				# command to open a new window.
				$propagated_event = $event->clone();
				$propagated_event->{currentfile} = $clicked_file;
				$self->handleopenwindow($propagated_event);
			} else {
				$propagated_event->{data} = "\r";
				$self->handleenter($propagated_event);
			}
		} elsif (!$on_name and $mbutton == BUTTON_LEFT) {
			$propagated_event->{data} = 'k8';
			$self->handlemark($propagated_event);
		} else {
			$propagated_event->{data} = 's';
			$self->handleshow($propagated_event);
		}
	}
	return 1; # must return true to fill $valid in sub handle()
}

=item handlemousepathjump(App::PFM::Event $event)

Handles a click in the directory path, and changes to this directory.
The parameter I<event> contains information about where the mouse was
clicked (See App::PFM::Event).

=cut

sub handlemousepathjump {
	my ($self, $event) = @_;
	my ($baselen, $skipsize, $selecteddir);
	my $screen     = $self->{_screen};
	my $mousecol   = $event->{mousecol};
	my $currentdir = $_pfm->state->directory->path;
	my $pathline   = $screen->pathline(
		$currentdir,
		$_pfm->state->directory->disk->{'device'},
		\$baselen,
		\$skipsize);
	# if part of the pathline has been left out, calculate the position
	# where the mouse would have clicked if the path had been complete
	if ($mousecol >= $baselen) {
		$mousecol += $skipsize;
	}
	$currentdir  =~ /^(.{$mousecol}	# 'mousecol' number of chars
						[^\/]*		# gobbling up all non-slash chars
						(?:\/|$))	# a slash or eoln
					  	([^\/]*)	# maybe another string of non-slash chars
					/x;
	$selecteddir = $1;
	$_pfm->browser->position_at($2);
	if ($selecteddir eq '' or
		$selecteddir eq $currentdir)
	{
		$self->handlemoreshow();
	} elsif ($screen->ok_to_remove_marks()) {
		if (!$_pfm->state->directory->chdir($selecteddir)) {
			$screen->display_error("$selecteddir: $!");
			$screen->set_deferred_refresh(R_SCREEN);
		}
	}
}

=item handlemouseheadingsort(App::PFM::Event $event)

Sorts the directory contents according to the heading clicked.

=cut

sub handlemouseheadingsort {
	my ($self, $event) = @_;
	my $currentlayoutline = $self->{_screen}->listing->currentlayoutline;
	my %sortmodes = @{FIELDS_TO_SORTMODE()};
	# get field character
	my $key = substr($currentlayoutline, $event->{mousecol}, 1);
#	if ($key eq '*') {
#		goto &handlemarkall;
#	}
	# translate field character to sort mode character
	$key = $sortmodes{$key};
	if ($key) {
		$key = uc($key) if $event->{mousebutton} != BUTTON_LEFT;
		# we don't need locale-awareness here
		$key =~ tr/A-Za-z/a-zA-Z/ if ($_pfm->state->sort_mode eq $key);
		$_pfm->state->sort_mode($key);
		$_pfm->browser->position_at(
			$_pfm->browser->currentfile->{name}, { force => 0, exact => 1 });
	}
	$self->{_screen}->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlemousemenucommand(App::PFM::Event $event)

Starts the menu command that was clicked on.

=cut

sub handlemousemenucommand {
	my ($self, $event) = @_;
	my $vscreenwidth = $self->{_screen}->screenwidth - 9* $_pfm->state->{multiple_mode};
	# hack: add 'Multiple' marker. We need a special character
	# for multiple mode so that the regexp below can recognize it
	my $M     = "0";
	my $menu  = ($_pfm->state->{multiple_mode} ? "${M}ultiple " : '') .
						$self->{_screen}->frame->_fitbanner(
							$self->{_screen}->frame->_getmenu(), $vscreenwidth);
	my $left  = $event->{mousecol} - 1;
	my $right = $self->{_screen}->screenwidth - $event->{mousecol} - 1;
	my $choice;
	$menu =~ /^					# anchor
		(?:.{0,$left}\s|)		# (empty string left  || chars then space)
		[-[:lower:]]*			# any nr. of lowercase chars or minus
		([[:upper:]<>$M])		# one uppercase char, multiple mark, or pan char
		[-[:lower:]]*			# any nr. of lowercase chars or minus
		(?:\s.{0,$right}|)		# (empty string right || space then chars)
		$/x;					# anchor
	$choice = $1;
	if ($choice eq 'Q') {
		$choice = 'q';
	} elsif ($choice eq $M) {
		$choice = 'k10';
	}
#	$self->{_screen}->at(1,0)->puts("L-$left :$choice: R-$right    ");
	my $propagated_event        = $event->clone();
	$propagated_event->{type}   = 'key';
	$propagated_event->{data}   = $choice;
	$propagated_event->{origin} = $self;
	return $self->handle($propagated_event);
}

=item handlemousefootercommand(App::PFM::Event $event)

Starts the footer command that was clicked on.

=cut

sub handlemousefootercommand {
	my ($self, $event) = @_;
	my $menu  = $self->{_screen}->frame->_fitbanner(
					$self->{_screen}->frame->_getfooter(),
					$self->{_screen}->screenwidth);
	my $left  = $event->{mousecol} - 1;
	my $right = $self->{_screen}->screenwidth - $event->{mousecol} - 1;
	my $choice;
	$menu =~ /^					# anchor
		(?:.{0,$left}\s|)		# (empty string left  || chars then space)
		(?:						#
			(\W(?=-)			# non-alphabetic, before a dash (mode toggles)
			|F\d+(?=-)			# or F<digits>, before a dash
			|[<>]				# or pan character
			)					#
			\S*					# any nr. of non-space chars
		)						#
		(?:\s.{0,$right}|)		# (empty string right || space then chars)
		$/x;					# anchor
	($choice = $1) =~ s/^F/k/;	# transform F12 to k12
#	$self->{_screen}->at(1,0)->puts("L-$left :$choice: R-$right    ");
	my $propagated_event        = $event->clone();
	$propagated_event->{type}   = 'key';
	$propagated_event->{data}   = $choice;
	$propagated_event->{origin} = $self;
	return $self->handlecyclesort($propagated_event) if ($choice eq 'k6');
	return $self->handle($propagated_event);
}

=item handlemore(App::PFM::Event $event)

Shows the menu of B<M>ore commands, and handles the user's choice.

=cut

sub handlemore {
	my ($self, $event) = @_;
	my $frame  = $self->{_screen}->frame;
	my $oldpan = $frame->currentpan();
	$frame->currentpan(0);
	my $key;
#	$self->{_screen}->clear_footer()->noecho()
#		->set_deferred_refresh(R_MENU);
	my $headerlength = $self->{_screen}->noecho()->set_deferred_refresh(R_MENU)
		->show_frame({
			footer => FOOTER_MORE,
			menu   => MENU_MORE,
		});
	MORE_PAN: {
		$key = $self->{_screen}->at(0, $headerlength+1)->getch();
		for ($key) {
			/^s$/io		and $self->handlemoreshow($event),		last MORE_PAN;
			/^m$/io		and $self->handlemoremake($event),		last MORE_PAN;
			/^c$/io		and $self->handlemoreconfig($event),	last MORE_PAN;
			/^e$/io		and $self->handlemoreedit($event),		last MORE_PAN;
			/^h$/io		and $self->handlemoreshell(),			last MORE_PAN;
			/^a$/io		and $self->handlemoreacl($event),		last MORE_PAN;
			/^b$/io		and $self->handlemorebookmark($event),	last MORE_PAN;
			/^g$/io		and $self->handlemorego($event),		last MORE_PAN;
			/^f$/io		and $self->handlemorefifo($event),		last MORE_PAN;
			/^w$/io		and $self->handlemorehistwrite(),		last MORE_PAN;
			/^t$/io		and $self->handlemorealtscreen(),		last MORE_PAN;
			/^p$/io		and $self->handlemorephyspath(),		last MORE_PAN;
			/^v$/io		and $self->handlemoreversion(),			last MORE_PAN;
			/^k6$/io	and $self->handlemoremultisort($event),	last MORE_PAN;
			/^[<>]$/io	and do {
				$event->{data} = $key;
				$self->handlepan($event, MENU_MORE);
				$headerlength = $frame->show_menu(MENU_MORE);
				$frame->show_footer(FOOTER_MORE);
				redo MORE_PAN;
			};
			# invalid key
			$self->{_screen}->flash();
		}
	}
	$frame->currentpan($oldpan);
}

=item handlemoreshow(App::PFM::Event $event)

Does a chdir() to any directory (B<M>ore - B<S>how).

=cut

sub handlemoreshow {
	my ($self, $event) = @_;
	my $screen   = $self->{_screen};
	my ($newname);
	$screen->set_deferred_refresh(R_MENU);
	return if !$screen->ok_to_remove_marks();
	$screen->show_frame({
		footer => FOOTER_NONE,
	});
	$screen->at(0,0)->clreol()->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'Directory Pathname: ',
	});
	$screen->raw_noecho();
	return if $newname eq '';
	$self->_expand_escapes(QUOTE_OFF, $newname, $event->{currentfile});
	if (!$_pfm->state->directory->chdir($newname)) {
		$screen->set_deferred_refresh(R_PATHINFO)
			->display_error("$newname: $!");
	}
}

=item handlemoremake(App::PFM::Event $event)

Makes a new directory (B<M>ore - B<M>ake).

=cut

sub handlemoremake {
	my ($self, $event) = @_;
	my ($newname);
	my $screen = $self->{_screen};
	$screen->set_deferred_refresh(R_MENU);
	$screen->show_frame({
		footer => FOOTER_NONE,
	});
	$screen->at(0,0)->clreol()->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'New Directory Pathname: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $event->{currentfile});
	$screen->raw_noecho();
	return if $newname eq '';
	# don't use perl's mkdir: we want to be able to use -p
	if (system "mkdir -p \Q$newname\E") {
		$screen->set_deferred_refresh(R_SCREEN)
			->at(0,0)->clreol()->display_error('Make directory failed');
	} elsif (!$screen->ok_to_remove_marks()) {
		if ($newname !~ m!/!) {
			$_pfm->state->directory->addifabsent(
				entry => $newname,
				mark => ' ',
				white => '',
				refresh => TRUE);
			$_pfm->browser->position_at($newname);
		}
	} elsif (!$_pfm->state->directory->chdir($newname)) {
		$screen->at(0,0)->clreol()->display_error("$newname: $!");
	}
}

=item handlemoreconfig(App::PFM::Event $event)

Opens the current config file (F<.pfmrc>) in the configured editor
(B<M>ore - B<C>onfig).

=cut

sub handlemoreconfig {
	my ($self, $event) = @_;
	my $config         = $_pfm->config;
	my $olddotdot      = $config->{dotdot_mode};
	my $config_editor  = $config->{fg_editor} || $config->{editor};
	$self->{_screen}->at(0,0)->clreol()
		->set_deferred_refresh(R_CLRSCR);
	if (system $config_editor, $config->location()) {
		$self->{_screen}->at(1,0)->display_error('Editor failed');
	} else {
		$config->read($config->READ_AGAIN);
		$config->parse();
		if ($olddotdot != $config->{dotdot_mode}) {
			# there is no key to toggle dotdot mode, therefore
			# it is allowed to switch dotdot mode here.
			$_pfm->browser->position_at($event->{currentfile}{name});
			$_pfm->state->directory->set_dirty(D_SORT);
		}
	}
}

=item handlemoreedit(App::PFM::Event $event)

Opens any file in the configured editor (B<M>ore - B<E>dit).

=cut

sub handlemoreedit {
	my ($self, $event) = @_;
	my $newname;
	$self->{_screen}->show_frame({
		footer => FOOTER_NONE,
	});
	$self->{_screen}->at(0,0)->clreol()->cooked_echo()
		->set_deferred_refresh(R_CLRSCR);
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'Filename to edit: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $event->{currentfile});
	if (system $_pfm->config->{editor}." \Q$newname\E") {
		$self->{_screen}->display_error('Editor failed');
	}
	$self->{_screen}->raw_noecho();
}

=item handlemoreshell()

Starts the user's login shell (B<M>ore - sB<H>ell).

=cut

sub handlemoreshell {
	my ($self) = @_;
	my $chdirautocmd = $_pfm->config->{chdirautocmd};
	$self->{_screen}->alternate_off()->clrscr()->cooked_echo()
		->set_deferred_refresh(R_CLRSCR);
#	@ENV{qw(ROWS COLUMNS)} = ($screenheight + $BASELINE + 2, $screenwidth);
	system ($ENV{SHELL} ? $ENV{SHELL} : 'sh'); # most portable
	$self->{_screen}->pressanykey(); # will also put the screen back in raw mode
	$self->{_screen}->alternate_on() if $_pfm->config->{altscreen_mode};
	system("$chdirautocmd") if length($chdirautocmd);
}

=item handlemoreacl(App::PFM::Event $event)

Allows the user to edit the file's Access Control List (B<M>ore - B<A>cl).

=cut

sub handlemoreacl {
    my ($self, $event) = @_;
	my $screen = $self->{_screen};
	# we count on the OS-specific command to start an editor.
	$screen->alternate_off()->clrscr()->at(0,0)->cooked_echo();
	my $do_this = sub {
		my $file = shift;
		unless ($self->{_os}->acledit($file->{name})) {
			$screen->neat_error($!);
		}
	};
	$_pfm->state->directory->apply($do_this, $event);
	$screen->pressanykey();
	$screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handlemorebookmark(App::PFM::Event $event)

Creates a bookmark to the current directory (B<M>ore - B<B>ookmark).

=cut

sub handlemorebookmark {
	my ($self, $event) = @_;
	my ($dest, $key, $prompt);# , $destfile
	# the footer has already been cleared by handlemore()
	# choice
	$self->_listbookmarks();
	$self->{_screen}->show_frame({
		headings => HEADING_BOOKMARKS,
		footer   => FOOTER_NONE,
		prompt   => 'Bookmark under which letter? ',
	});
	$key = $self->{_screen}->getch();
	return if $key eq "\r";
	# process key
	if ($key !~ /^[a-zA-Z]$/) {
		# the bookmark is undefined
		$self->{_screen}->at(0,0)->clreol()
				->display_error('Bookmark name not valid');
		return;
	}
	$_pfm->state->{_position}  = $event->{currentfile}{name};
	$_pfm->state->{_baseindex} = $event->{lunchbox}{baseindex};
	$_pfm->state($key, $_pfm->state->clone());
}

=item handlemorego(App::PFM::Event $event)

Shows a list of the current bookmarks, then offers the user a choice to
jump to one of them (B<M>ore - B<G>o).

=cut

sub handlemorego {
	my ($self, $event) = @_;
	my $browser = $_pfm->browser;
	my $screen  = $self->{_screen};
	my ($dest, $key, $prompt, $destfile, $success,
		$prevdir, $prevstate, $chdirautocmd);
	# the footer has already been cleared by handlemore()
	$self->_listbookmarks();
	# choice
	$prompt = 'Go to which bookmark? ';
	$key = $screen->at(0,0)->clreol()
		->putmessage($prompt)->getch();
	return if $key eq "\r";
	$dest = $_pfm->state($key);
	if ($dest eq '') {
		# the bookmark is undefined
		$screen->at(0,0)->clreol()
				->display_error('Bookmark not defined');
		return;
	} elsif (ref $dest) {
		# the bookmark is an already prepared state object
		$prevstate = $_pfm->state->clone();
		$prevdir   = $prevstate->directory->path;
		# go there
		$_pfm->state('S_MAIN', $dest->clone());
		# destination
		$dest = $dest->directory->path;
		# go there using bare chdir() - the state is already up to date
		if ($success = chdir $dest and $dest ne $prevdir) {
			# store the previous main state into S_PREV
			$_pfm->state('S_PREV', $prevstate);
			# restore the cursor position
			$browser->baseindex(  $_pfm->state->{_baseindex});
			$browser->position_at($_pfm->state->{_position});
			# autocommand
			$chdirautocmd = $_pfm->config->{chdirautocmd};
			system("$chdirautocmd") if length($chdirautocmd);
			$screen->set_deferred_refresh(R_SCREEN);
		} elsif (!$success) {
			# the state needs refreshing as we counted on being
			# able to chdir()
			$screen->at($screen->PATHLINE, 0)->clreol()
				->set_deferred_refresh(R_CHDIR)
				->display_error("$dest: $!");
			$_pfm->state->directory->set_dirty(D_ALL);
		}
	} else {
		# the bookmark is an uninitialized directory path
		$self->_expand_3456_escapes(QUOTE_OFF, $dest);
		$dest =~ s{/$}{/.};
		$destfile = basename $dest;
		$dest     = dirname  $dest;
		if (!$_pfm->state->directory->chdir($dest)) {
			$screen->set_deferred_refresh(R_PATHINFO)
				->display_error("$dest: $!");
			return;
		}
		if (defined $destfile) {
			# provide the force option because the chdir()
			# above may already have set the position_at
			$_pfm->browser->position_at($destfile, { force => 1 });
		}
		# commented out because we don't want to store the state object
#		$_pfm->state->prepare(); # unsets _dirty flags
		# store the prepared state
#		$_pfm->state->{_position}  = $browser->currentfile->{name};
#		$_pfm->state->{_baseindex} = $browser->baseindex;
#		$_pfm->state($key, $_pfm->state->clone());
	}
}

=item handlemorefifo(App::PFM::Event $event)

Handles creating a FIFO (named pipe) (B<M>ore - mkB<F>ifo).

=cut

sub handlemorefifo {
	my ($self, $event) = @_;
	my ($newname, $findindex);
	my $screen = $self->{_screen};
	$screen->show_frame({
		footer => FOOTER_NONE,
	});
	$screen->at(0,0)->clreol()
		->set_deferred_refresh(R_MENU)
		->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'New FIFO name: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $event->{currentfile});
	$screen->raw_noecho();
	return if $newname eq '';
	$screen->set_deferred_refresh(R_SCREEN);
	if (system "mkfifo \Q$newname\E") {
		$screen->display_error('Make FIFO failed');
		return;
	}
	# add newname to the current directory listing.
	$_pfm->state->directory->addifabsent(
		entry => $newname,
		mark => ' ',
		white => '',
		refresh => TRUE);
	$_pfm->browser->position_at($newname);
}

=item handlemorehistwrite()

Writes the histories and the bookmarks to file (B<M>ore - B<W>rite-history).

=cut

sub handlemorehistwrite {
	my ($self) = @_;
	$self->{_screen}->show_frame({
		footer => FOOTER_NONE,
	});
	$_pfm->history->write();
	$_pfm->config->write_bookmarks();
}


=item handlemorealtscreen()

Shows the alternate terminal screen (I<e.g.> for viewing the output of
a previous command) (B<M>ore - alB<T>screen).

=cut

sub handlemorealtscreen {
	my ($self) = @_;
	return unless $_pfm->config->{altscreen_mode};
	$self->{_screen}->set_deferred_refresh(R_CLRSCR)
		->alternate_off()->pressanykey();
}

=item handlemorephyspath()

Shows the canonical pathname of the current directory (B<M>ore - B<P>hysical).

=cut

sub handlemorephyspath {
	my ($self) = @_;
	$self->{_screen}->show_frame({
		footer => FOOTER_NONE,
	});
	$self->{_screen}->at(0,0)->clreol()
		->putmessage('Current physical path:')
		->path_info($self->{_screen}->PATH_PHYSICAL)
		->set_deferred_refresh(R_PATHINFO | R_MENU)
		->getch();
}

=item handlemoreversion()

Checks if the current directory is under version control,
and starts a job for the current directory if so (B<M>ore - B<V>ersion).

=cut

sub handlemoreversion {
	my ($self) = @_;
	$_pfm->state->directory->checkrcsapplicable();
}

=item handlemoremultisort(App::PFM::Event $event)

Handles asking for user input and setting multilevel sort mode.

=cut

sub handlemoremultisort {
	my ($self, $event) = @_;
	$self->handlesort($event, TRUE);
}

=item handleenter(App::PFM::Event $event)

Enter a directory or launch a file (B<ENTER>).

=cut

sub handleenter {
	my ($self, $event) = @_;
	my $currentfile    = $event->{currentfile};
	my $directory      = $_pfm->state->directory;
	my $pfmrc          = $_pfm->config->pfmrc;
	my $screen         = $self->{_screen};
	my $do_this;
	if ($self->_followmode($currentfile) =~ /^d/) {
		goto &handleentry;
	}
	$screen->at(0,0)->clreol()->at(0,0)->cooked_echo()
		->alternate_off();
	LAUNCH: foreach (split /,/, $_pfm->config->{launchby}) {
		# these functions return either:
		# - a code reference to be used in Directory->apply()
		# - a falsy value if no applicable launch command can be found
		/magic/     and $do_this = $self->launchbymagic(    $currentfile);
		/extension/ and $do_this = $self->launchbyextension($currentfile);
		/xbit/      and $do_this = $self->launchbyxbit(     $currentfile);
		# continue trying until one of the modes finds a launch command
		last LAUNCH if $do_this;
	}
	if (ref $do_this) {
		# a code reference: possible way to launch
		$currentfile->apply($do_this);
		$screen->set_deferred_refresh(R_CLRSCR)->pressanykey();
	} elsif (defined $do_this) {
		# an error message: the file type was unknown.
		# feed it to the pager instead.
		$screen->clrscr();
		if (system $_pfm->config->{pager}." \Q$currentfile->{name}\E")
		{
			$screen->display_error($!);
		}
		$screen->set_deferred_refresh(R_CLRSCR);
	} else {
		# 'launchby' contains no valid entries
		$screen->set_deferred_refresh(R_MENU)
			->display_error("No valid 'launchby' option in config file");
	}
	$screen->raw_noecho();
	$screen->alternate_on() if $_pfm->config->{altscreen_mode};
}

=item launchbyxbit(App::PFM::File $file)

Returns an anonymous subroutine for executing the file if it is executable;
otherwise, returns undef.

=cut

sub launchbyxbit {
	my ($self, $currentfile) = @_;
	my $do_this = '';
	return '' if ($self->_followmode($currentfile) !~ /[xsS]/);
	$do_this = sub {
		my $file = shift;
		$self->{_screen}->clrscr()->at(0,0)
			->puts("Launch executable $file->{name}\n");
		if (system "./\Q$file->{name}\E") {
			$self->{_screen}->display_error('Launch failed');
		}
	};
	return $do_this;
}

=item launchbymagic(App::PFM::File $file)

Determines the MIME type of a file, using its magic (see file(1)).

=cut

sub launchbymagic {
	my ($self, $currentfile) = @_;
	my $pfmrc   = $_pfm->config->pfmrc;
	my $magic   = `file \Q$currentfile->{name}\E`;
	my $do_this = '';
	my $re;
	MAGIC: foreach (grep /^magic\[/, keys %{$pfmrc}) {
		($re) = (/magic\[([^]]+)\]/);
		# this will produce errors if the regexp is invalid
		if (eval "\$magic =~ /$re/") {
			$do_this = $self->launchbymime($pfmrc->{$_});
			last MAGIC;
		}
	}
	return $do_this;
}

=item launchbyextension(App::PFM::File $file)

Determines the MIME type of a file by looking at its extension.

=cut

sub launchbyextension {
	my ($self, $currentfile) = @_;
	my $pfmrc   = $_pfm->config->pfmrc;
	my ($ext)   = ( $currentfile->{name} =~ /(\.[^\.]+?)$/ );
	my $do_this = '';
	if (exists $pfmrc->{"extension[*$ext]"}) {
		$do_this = $self->launchbymime($pfmrc->{"extension[*$ext]"});
	}
	return $do_this;
}

=item launchbymime(string $mime_type)

Returns an anonymous subroutine for executing the file according to
the definition for its MIME type.
If there is no such definition, reports an error and returns undef.


=cut

sub launchbymime {
	my ($self, $mime) = @_;
	my $pfmrc   = $_pfm->config->pfmrc;
	my $do_this = '';
	if (! exists $pfmrc->{"launch[$mime]"}) {
		$self->{_screen}
			->display_error("No launch command defined for type $mime\n");
		return '';
	}
	$do_this = sub {
		my $file = shift;
		my $command = $pfmrc->{"launch[$mime]"};
		$self->_expand_escapes(QUOTE_ON, $command, $file);
		$self->{_screen}->clrscr()->at(0,0)
			->puts("Launch type $mime\n$command\n");
		system $command and $self->{_screen}->display_error('Launch failed');
	};
	return $do_this;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
