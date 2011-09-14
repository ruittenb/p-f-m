#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::CommandHandler 1.23
#   
# Name:			App::PFM::CommandHandler
# Version:		1.23
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-04
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
use App::PFM::History		qw(:constants); # imports the H_* constants
use App::PFM::Directory 	qw(:constants); # imports the D_* and M_* constants
use App::PFM::Screen		qw(:constants); # imports the R_* constants
use App::PFM::Screen::Frame qw(:constants); # imports the MENU_*, HEADING_*
#											#         and FOOTER_* constants

use POSIX qw(strftime mktime);
use Config;

use strict;

use constant {
	FALSE		=> 0,
	TRUE		=> 1,
	QUOTE_OFF	=> 0,
	QUOTE_ON	=> 1,
	SPAWNEDCHAR => '*',
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

our ($_pfm, $_screen);
our ($command);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm    = $pfm;
	$_screen = $pfm->screen;
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
 <               shift commands menu left         .    filter dotfiles          
 >               shift commands menu right        %    filter whiteouts         
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
		my $name = $_screen->colored('bold', 'pfm');
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
   Any bug, comment or suggestion is welcome in order to update this product.

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
	$_screen->set_deferred_refresh(R_PATHINFO);
	if ($_pfm->state->{multiple_mode} and
		$testname !~ /(?<!$qe)(?:$qe$qe)*${e}[127]/ and !-d $testname)
	{
		$_screen->at(0,0)->putmessage(
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
	$_screen->at(0,0)->clreol()->cooked_echo();
	$boundarytime = $_pfm->history->input({
		history       => H_TIME,
		prompt        => $prompt,
		default_input => strftime ("%Y-%m-%d %H:%M.%S", localtime time),
	});
	# show_menu is done in handleinclude
	$_screen->raw_noecho();
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
	$_screen->at(0,0)->clreol()->cooked_echo();
	$boundarysize = $_pfm->history->keyboard->readline($prompt);
	# show_menu is done in handleinclude
	$_screen->raw_noecho();
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
	$_screen->at(0,0)->clreol()->cooked_echo();
	$wildfilename = $_pfm->history->input({
		history => H_REGEX,
		prompt  => $prompt,
	});
	# show_menu is done in handleinclude
	$_screen->raw_noecho();
	eval "/$wildfilename/";
	if ($@) {
		$_screen->display_error($@)->key_pressed($_screen->IMPORTANTDELAY);
		$wildfilename = '^$'; # clear illegal regexp
	}
	return $wildfilename;
}

=item _listbookmarks()

List the bookmarks from the %states hash.

=cut

sub _listbookmarks {
	my ($self) = @_;
	my $printline       = $_screen->BASELINE;
	my $filerecordcol   = $_screen->listing->filerecordcol;
	my @heading         = $_screen->frame->bookmark_headings;
	my $bookmarkpathlen = $heading[2];
	my $spacing         =
		' ' x ($_screen->screenwidth - $_screen->diskinfo->infolength);
	my ($dest, $spawned, $overflow);
	# headings
	$_screen
		->set_deferred_refresh(R_SCREEN)
		->show_frame({
			headings => HEADING_BOOKMARKS,
			footer   => FOOTER_NONE,
		});
	# list bookmarks
	foreach (@{$_pfm->BOOKMARKKEYS}) {
		last if ($printline > $_screen->BASELINE + $_screen->screenheight);
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
			$dest .= ($overflow ? $_screen->listing->NAMETOOLONGCHAR : ' ');
		}
		$_screen->at($printline++, $filerecordcol)
			->puts(sprintf($heading[0], $_, $spawned, $dest));
	}
	foreach ($printline .. $_screen->BASELINE + $_screen->screenheight) {
		$_screen->at($printline++, $filerecordcol)->puts($spacing);
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
	$_screen->at(0,0)->clreol()
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
							and $self->handleentry($_),					  last;
		/^[\cE\cY]$/o		and $self->handlescroll($_),				  last;
		/^l$/o				and $self->handlekeyell($_),				  last;
		/^k5$/o				and $self->handlerefresh(),					  last;
		/^[cr]$/io			and $self->handlecopyrename($_),			  last;
		/^[yo]$/io			and $self->handlecommand($_),				  last;
		/^e$/io				and $self->handleedit(),					  last;
		/^(?:d|del)$/io		and $self->handledelete(),					  last;
		/^[ix]$/io			and $self->handleinclude($_),				  last;
		/^\r$/io			and $self->handleenter(),					  last;
		/^s$/io				and $self->handleshow(),					  last;
		/^kmous$/o			and $handled = $self->handlemousedown($event),last;
		/^k7$/o				and $self->handleswap(),					  last;
		/^k10$/o			and $self->handlemultiple(),				  last;
		/^m$/io				and $self->handlemore(),					  last;
		/^p$/io				and $self->handleprint(),					  last;
		/^L$/o				and $self->handlelink(),					  last;
		/^n$/io				and $self->handlename(),					  last;
		/^(k8| )$/o			and $self->handlemark(),					  last;
		/^k11$/o			and $self->handlerestat(),					  last;
		/^[\/f]$/io			and $self->handlefind(),					  last;
		/^[<>]$/io			and $self->handlepan($_, MENU_SINGLE),		  last;
		/^(?:k3|\cL|\cR)$/o	and $self->handlefit(),						  last;
		/^t$/io				and $self->handletime(),					  last;
		/^a$/io				and $self->handlechmod(),					  last;
		/^q$/io				and $handled = $self->handlequit($_),		  last;
		/^k6$/o				and $self->handlesinglesort(),				  last;
		/^(?:k1|\?)$/o		and $self->handlehelp(),					  last;
		/^k2$/o				and $self->handleprev(),					  last;
		/^\.$/o				and $self->handledot(),						  last;
		/^k9$/o				and $self->handlelayouts(),					  last;
		/^k4$/o				and $self->handlecolor(),					  last;
		/^\@$/o				and $self->handleperlcommand(),				  last;
		/^u$/io				and $self->handlechown(),					  last;
		/^v$/io				and $self->handleversion(),					  last;
		/^z$/io				and $self->handlesize(),					  last;
		/^g$/io				and $self->handletarget(),					  last;
		/^k12$/o			and $self->handlemousemode(),				  last;
		/^=$/o				and $self->handleident(),					  last;
		/^\*$/o				and $self->handleradix(),					  last;
		/^!$/o				and $self->handleclobber(),					  last;
		/^"$/o				and $self->handlepathmode(),				  last;
		/^w$/io				and $self->handleunwo(),					  last;
		/^%$/o				and $self->handlewhiteout(),				  last;
		$handled = 0;
		$_screen->flash();
	}
	return $handled;
}

=item handlepan(char $key, int $menu_mode)

Handles the pan keys B<E<lt>> and B<E<gt>>.
This uses the B<MENU_> constants as defined in App::PFM::Screen::Frame.

=cut

sub handlepan {
	my ($self, $key, $mode) = @_;
	$_screen->frame->pan($key, $mode);
}

=item handlescroll(char $key)

Handles B<CTRL-E> and B<CTRL-Y>, which scroll the current view of
the directory.

=cut

sub handlescroll {
	my ($self, $key) = @_;
	my $up = ($key =~ /^\cE$/o);
	my $screenheight  = $_screen->screenheight;
	my $browser       = $_pfm->browser;
	my $baseindex     = $browser->baseindex;
	my $currentline   = $browser->currentline;
	my $showncontents = $_pfm->state->directory->showncontents;
	return 0 if ( $up and
				  $baseindex == $#$showncontents and
				  $currentline == 0)
			 or (!$up and $baseindex == 0);
	my $displacement = $up - ! $up;
	$baseindex   += $displacement;
	$currentline -= $displacement if $currentline-$displacement >= 0
								 and $currentline-$displacement <= $screenheight;
	$browser->setview($currentline, $baseindex);
}

=item handleprev()

Handles the B<previous> command (B<F2>).

=cut

sub handleprev {
	my ($self) = @_;
	my $browser = $_pfm->browser;
	my $prevdir = $_pfm->state('S_PREV')->directory->path;
	my $chdirautocmd;
	if (chdir $prevdir) {
		# store current cursor position
		$_pfm->state->{_position}  = $browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# perform the swap
		$_pfm->swap_states('S_MAIN', 'S_PREV');
		# restore the cursor position
		$browser->baseindex(  $_pfm->state->{_baseindex});
		$browser->position_at($_pfm->state->{_position});
		# autocommand
		$chdirautocmd = $_pfm->config->{chdirautocmd};
		system("$chdirautocmd") if length($chdirautocmd);
		$_screen->set_deferred_refresh(R_SCREEN);
	} else {
		$_screen->set_deferred_refresh(R_MENU);
	}
}

=item handleswap()

Swaps to an alternative directory (B<F7>).

=cut

sub handleswap {
	my ($self) = @_;
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
			$_pfm->state->{_position}  = $browser->currentfile->{name};
			$_pfm->state->{_baseindex} = $browser->baseindex;
			# perform the swap
			$_pfm->swap_states('S_MAIN', 'S_SWAP');
			# continue below
		} else {
			# --------------------------------------------------
			# there is a non-persistent swap state
			# --------------------------------------------------
			# swap back if ok_to_remove_marks
			if (!$_screen->ok_to_remove_marks()) {
				$_screen->set_deferred_refresh(R_FRAME);
				return;
			}
			# perform the swap back
			$_pfm->state('S_MAIN', $_pfm->state('S_SWAP'));
			# destroy the swap state
			$_pfm->state('S_SWAP', 0);
			# continue below
		}
		# set refresh already (we may be swapping to '.')
		$_screen->set_deferred_refresh(R_SCREEN);
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
			$_screen->at($_screen->PATHLINE, 0)->clreol()
				->set_deferred_refresh(R_CHDIR)
				->display_error("$nextdir: $!");
			$_pfm->state->directory->set_dirty(D_ALL);
		}
	} else {
		# --------------------------------------------------
		# there is no swap state yet
		# --------------------------------------------------
		# ask and swap forward
		$_screen->at(0,0)->clreol()->cooked_echo();
		$nextdir = $_pfm->history->input({
			history => H_PATH,
			prompt  => $prompt
		});
		$_screen->raw_noecho()
			->set_deferred_refresh(R_FRAME);
		return if $nextdir eq '';
		# set refresh already (we may be swapping to '.')
		$_screen->set_deferred_refresh(R_SCREEN);
		# store current cursor position
		$_pfm->state->{_position}  = $browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# store the main state
		$_pfm->state('S_SWAP', $_pfm->state->clone());
		# toggle swap mode flag
		$browser->swap_mode(!$browser->swap_mode);
		# fix destination
		$self->_expand_escapes(QUOTE_OFF, $nextdir, $browser->currentfile);
		# go there using the directory's chdir() (TODO $swapping flag behavior?)
		if ($_pfm->state->directory->chdir($nextdir, 0)) {
			# set the cursor position
			$browser->baseindex(0);
			$_pfm->state->{multiple_mode} = 0;
			$_pfm->state->sort_mode($_pfm->config->{defaultsortmode} || 'n');
			$_screen->set_deferred_refresh(R_CHDIR);
		}
	}
}

=item handlerefresh()

Handles the command to refresh the current directory (B<F5>).

=cut

sub handlerefresh {
#	my ($self) = @_;
	if ($_screen->ok_to_remove_marks()) {
		$_screen->set_deferred_refresh(R_SCREEN);
		$_pfm->state->directory->set_dirty(D_FILELIST);
	}
}

=item handlewhiteout()

Toggles the filtering of whiteout files (key B<%>).

=cut

sub handlewhiteout {
#	my ($self) = @_;
	my $browser = $_pfm->browser;
	toggle($_pfm->state->{white_mode});
	# the directory object schedules a position_at when
	# $d->refresh() is called and the directory is dirty.
	$_screen->frame->update_headings();
	$_screen->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_FILTER);
}

=item handlemultiple()

Toggles multiple mode (B<F10>).

=cut

sub handlemultiple {
#	my ($self) = @_;
	toggle($_pfm->state->{multiple_mode});
	$_screen->set_deferred_refresh(R_MENU);
}

=item handledot()

Toggles the filtering of dotfiles (key B<.>).

=cut

sub handledot {
#	my ($self) = @_;
	my $browser = $_pfm->browser;
	toggle($_pfm->state->{dot_mode});
	# the directory object schedules a position_at when
	# $d->refresh() is called and the directory is dirty.
	$_screen->frame->update_headings();
	$_screen->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_FILTER);
}

=item handlecolor()

Cycles through color modes (B<F4>).

=cut

sub handlecolor {
#	my ($self) = @_;
	$_screen->select_next_color();
}

=item handlemousemode()

Handles turning mouse mode on or off (B<F12>).

=cut

sub handlemousemode {
#	my ($self) = @_;
	my $browser = $_pfm->browser;
	$browser->mouse_mode(!$browser->mouse_mode);
}

=item handlelayouts()

Handles moving on to the next configured layout (B<F9>).

=cut

sub handlelayouts {
#	my ($self) = @_;
	$_screen->listing->select_next_layout();
}

=item handlefit()

Recalculates the screen size and adjusts the layouts (B<F3>).

=cut

sub handlefit {
#	my ($self) = @_;
	$_screen->fit();
}

=item handleident()

Calls the diskinfo class to cycle through showing
the username, hostname or both (key B<=>).

=cut

sub handleident {
#	my ($self) = @_;
	$_screen->diskinfo->select_next_ident();
}

=item handleclobber()

Toggles between clobbering files automatically, or prompting
before overwrite (key B<!>.

=cut

sub handleclobber {
	my ($self) = @_;
	$self->clobber_mode(!$self->{_clobber_mode});
	$_screen->set_deferred_refresh(R_FOOTER);
}

=item handlepathmode()

Toggles between logical and physical path mode (key B<">).

=cut

sub handlepathmode {
#	my ($self) = @_;
	my $directory = $_pfm->state->directory;
	$directory->path_mode($directory->path_mode eq 'phys' ? 'log' : 'phys');
}

=item handleradix()

Toggles between octal and hexadecimal radix (key B<*>), which is used for
showing nonprintable characters in the B<N>ame command.

=cut

sub handleradix {
#	my ($self) = @_;
	my $state = $_pfm->state;
	$state->{radix_mode} = ($state->{radix_mode} eq 'hex' ? 'oct' : 'hex');
	$_screen->set_deferred_refresh(R_FOOTER);
}

=item handlequit(char $key)

Handles the B<q>uit and quick B<Q>uit commands.

=cut

sub handlequit {
	my ($self, $key) = @_;
	my $confirmquit = $_pfm->config->{confirmquit};
	return 'quit' if isno($confirmquit);
	return 'quit' if $key eq 'Q'; # quick quit
	return 'quit' if
		($confirmquit =~ /marked/i and !$_screen->diskinfo->mark_info);
	$_screen->show_frame({
			footer => FOOTER_NONE,
			prompt => 'Are you sure you want to quit [Y/N]? '
	});
	my $sure = $_screen->getch();
	return 'quit' if ($sure =~ /y/i);
	$_screen->set_deferred_refresh(R_MENU | R_FOOTER);
	return 0;
}

=item handleperlcommand()

Handles executing a Perl command (key B<@>).

=cut

sub handleperlcommand {
	my ($self) = @_;
	my $perlcmd;
	# for ease of use when debugging
	my $pfm            = $_pfm;
	my $config         = $_pfm->config;
	my $os             = $_pfm->os;
	my $jobhandler     = $_pfm->jobhandler;
	my $commandhandler = $_pfm->commandhandler;
	my $history        = $_pfm->history;
	my $screen         = $_screen;
	my $listing        = $screen->listing;
	my $frame          = $screen->frame;
	my $browser        = $_pfm->browser;
	my $currentfile    = $browser->currentfile;
	my $state          = $_pfm->state;
	my $directory      = $state->directory;
	# now do!
	$_screen->listing->markcurrentline('@'); # disregard multiple_mode
	$_screen->show_frame({
		footer => FOOTER_NONE,
		prompt => 'Enter Perl command:'
	});
	$_screen->at($_screen->PATHLINE,0)->clreol()->cooked_echo();
	$perlcmd = $_pfm->history->input({ history => H_PERLCMD });
	$_screen->raw_noecho();
	eval $perlcmd;
	$_screen->display_error($@) if $@;
	$_screen->set_deferred_refresh(R_SCREEN);
}

=item handlehelp()

Shows a help page with an overview of commands (B<F1>).

=cut

sub handlehelp {
	my ($self) = @_;
	my $pages = 3;
	my $page  = 1;
	my ($key, $prompt);
	while ($page <= $pages) {
		$_screen->clrscr()->cooked_echo();
		$prompt = $self->_helppage($page);
		$key = $_screen->raw_noecho()->puts($prompt)->getch();
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
	$_screen->set_deferred_refresh(R_CLRSCR);
}

=item handleentry(char $key)

Handles entering or leaving a directory (left arrow, right arrow,
B<ESC>, B<BS>, B<h>, B<l> (if on a directory), B<ENTER> (if on a
directory)).

=cut

sub handleentry {
	my ($self, $key) = @_;
	my ($tempptr, $nextdir, $success, $direction);
	my $currentdir = $_pfm->state->directory->path;
	if ( $key =~ /^(?:kl|h|\e|\cH)$/io ) {
		$nextdir   = '..';
		$direction = 'up';
	} else {
		$nextdir   = $_pfm->browser->currentfile->{name};
		$direction = $nextdir eq '..' ? 'up' : 'down';
	}
	return if ($nextdir    eq '.');
	return if ($currentdir eq '/' && $direction eq 'up');
	return if !$_screen->ok_to_remove_marks();
	$success = $_pfm->state->directory->chdir($nextdir, 0, $direction);
	unless ($success) {
		$_screen->at(0,0)->clreol()->display_error($!);
		$_screen->set_deferred_refresh(R_MENU);
	}
	return $success;
}

=item handlemark()

Handles marking (including or excluding) a file (key B<SPACE>
or B<F8>).

=cut

sub handlemark {
	my ($self) = @_;
	my $currentfile  = $_pfm->browser->currentfile;
	my $was_selected = $currentfile->{selected} eq M_MARK;
	if ($was_selected) {
		$_pfm->state->directory->exclude($currentfile, ' ');
	} else {
		$_pfm->state->directory->include($currentfile);
	}
	# redraw the line now, because we could be moving on
	# to the next file now (space command)
	$_screen->listing->highlight_off();
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
	$_screen->set_deferred_refresh(R_SCREEN);
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
	$_screen->set_deferred_refresh(R_SCREEN);
}

=item handlekeyell()

Handles the lowercase B<l> key: enter the directory or create a link.

=cut

sub handlekeyell {
	my ($self) = @_;
	# small l only
	if ($_pfm->browser->currentfile->{type} eq 'd') {
		# this automagically passes the args to handleentry()
		goto &handleentry;
	} else {
		goto &handlelink;
	}
}

=item handlerestat()

Re-executes a stat() on the current (or selected) files (B<F11>).

=cut

sub handlerestat {
#	my ($self) = @_;
	$_pfm->state->directory->apply(sub {});
}

=item handlelink()

Creates a hard or symbolic link (B<L>ink as uppercase B<L>, or
lowercase B<l> if on a non-directory).

=cut

sub handlelink {
	my ($self) = @_;
	my ($newname, $do_this, $testname, $headerlength, $absrel, $histpush);
	my @lncmd = $self->{_clobber_mode} ? qw(ln -f) : qw(ln);
	
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_FRAME | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_FRAME);
		$_screen->listing->markcurrentline('L');
		$histpush = $_pfm->browser->currentfile->{name};
	}
	
	$headerlength = $_screen->show_frame({
		menu => MENU_LNKTYPE,
	});
	$absrel = lc $_screen->at(0, $headerlength+1)->getch();
	return unless $absrel =~ /^[arh]$/;
	push @lncmd, '-s' unless $absrel eq 'h';
	
	$_screen->at(0,0)->clreol()->cooked_echo();
	my $prompt = 'Name of new '.
		( $absrel eq 'r' ? 'relative symbolic'
		: $absrel eq 'a' ? 'absolute symbolic' : 'hard') . ' link: ';
	
	chomp($newname = $_pfm->history->input({
		history       => H_PATH,
		prompt        => $prompt,
		history_input => $histpush,
	}));
	$_screen->raw_noecho();
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
			$_screen->neat_error('Linking failed');
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
	$_pfm->state->directory->apply($do_this);
}

=item handlesinglesort()

Handles asking for user input and setting single-level sort mode.

=cut

sub handlesinglesort {
	my ($self) = @_;
	$self->handlesort(FALSE);
}

=item handlesort( [ bool $multilevel ] )

Handles sorting the current directory (B<F6>).
The I<multilevel> argument indicates if the user must be offered
the possibility of entering a string of characters instead of
just a single one.

=cut

sub handlesort {
	my ($self, $multilevel) = @_;
	my $printline = $_screen->BASELINE;
	my $infocol   = $_screen->diskinfo->infocol;
	my $frame     = $_screen->frame;
	my %sortmodes = @{$_pfm->state->SORTMODES()};
	my ($i, $newmode, $menulength);
	$menulength = $frame->show({
		menu     => MENU_SORT,
		footer   => FOOTER_NONE,
		headings => HEADING_SORT,
	});
	$_screen->diskinfo->clearcolumn();
	# we can't use foreach (keys %sortmodes) because we would lose ordering
	foreach (grep { ($i += 1) %= 2 } @{$_pfm->state->SORTMODES()}) {
		# keep keys, skip values
		last if ($printline > $_screen->BASELINE + $_screen->screenheight);
		next if /[[:upper:]]/;
		$_screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s', $_, $sortmodes{$_}));
	}
	if ($multilevel) {
		$_screen->at(0,0)->clreol()->cooked_echo();
		chomp($newmode = $_pfm->history->input({
			history => H_MODE,
			prompt  => 'Sort by which modes? (uppercase=reverse): ',
		}));
		$_screen->raw_noecho();
	} else {
		$newmode = $_screen->at(0, $menulength)->getch();
	}
	$_screen->set_deferred_refresh(R_SCREEN);
	$_screen->diskinfo->clearcolumn();
	return if $newmode eq '';
	# find out if the resulting mode equals the newmode
	if ($newmode eq $_pfm->state->sort_mode($newmode)) {
		# if it has been set
		$_pfm->browser->position_at(
			$_pfm->browser->currentfile->{name}, { force => 0, exact => 1 });
	}
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlecyclesort()

Cycles through sort modes. Initiated by a mouse click on the 'Sort'
footer region.

=cut

sub handlecyclesort {
	my ($self) = @_;
	my @mode_to   = split(//, $_pfm->config->{sortcycle});
	my @mode_from = ($mode_to[-1], @mode_to);
	pop @mode_from;
	my %translations;
	@translations{@mode_from} = @mode_to;
	my $newmode = $translations{$_pfm->state->sort_mode} || $mode_to[0];
	$_pfm->state->sort_mode($newmode);
	$_pfm->browser->position_at(
		$_pfm->browser->currentfile->{name}, { force => 0, exact => 1 });
	$_screen->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlename()

Shows all chacacters of the filename in a readable manner (B<N>ame).

=cut

sub handlename {
	my ($self) = @_;
	my $numformat   = ${NUMFORMATS()}{$_pfm->state->{radix_mode}};
	my $browser     = $_pfm->browser;
	my $workfile    = $browser->currentfile->clone();
	my $screenline  = $browser->currentline + $_screen->BASELINE;
	my $filenamecol = $_screen->listing->filenamecol;
	my $trspace     = $_pfm->config->{trspace};
	my ($line, $linecolor);
	$_screen->listing->markcurrentline('N'); # disregard multiple_mode
	for ($workfile->{name}, $workfile->{target}) {
		s/\\/\\\\/;
		s{([${trspace}\177[:cntrl:]]|[^[:ascii:]])}
		 {'\\' . sprintf($numformat, unpack('C', $1))}eg;
	}
	$line = $workfile->{name} . $workfile->filetypeflag() .
			(length($workfile->{target}) ? ' -> ' . $workfile->{target} : '');
	$linecolor =
		$_pfm->config->{framecolors}{$_screen->color_mode}{highlight};
	
	$_screen->at($screenline, $filenamecol)
		->putcolored($linecolor, $line, " \cH");
	$_screen->listing->applycolor(
		$screenline, $_screen->listing->FILENAME_LONG, $workfile);
	if ($_screen->noecho()->getch() eq '*') {
		$self->handleradix();
		$_screen->echo()->at($screenline, $filenamecol)
			->puts(' ' x length $line)
			->frame->show_footer(FOOTER_SINGLE);
		goto &handlename;
	}
	if ($filenamecol < $_screen->diskinfo->infocol &&
		$filenamecol + length($line) >= $_screen->diskinfo->infocol or
		$filenamecol + length($line) >= $_screen->screenwidth)
	{
		$_screen->set_deferred_refresh(R_CLRSCR);
	}
}

=item handlefind()

Prompts for a filename to find, then positions the cursor at that file.
B<Find> or key B</>.

=item handlefind_incremental()

Prompts for a filename to find, and positions the cursor while the name
is typed (incremental find). Only applicable if the current sort_mode
is by name (ascending or descending).
B<Find> or key B</>.

=cut

sub handlefind {
	my ($self) = @_;
	if (lc($_pfm->state->sort_mode) eq 'n') {
		goto &handlefind_incremental;
	}
	my ($findme, $file);
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	($findme = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'File to find: ',
	})) =~ s/\/$//;
	if ($findme =~ /\//) { $findme = basename($findme) };
	$_screen->raw_noecho()->set_deferred_refresh(R_MENU);
	return if $findme eq '';
	FINDENTRY:
	foreach $file (sort by_name @{$_pfm->state->directory->showncontents}) {
		if ($findme le $file->{name}) {
			$_pfm->browser->position_at($file->{name});
			last FINDENTRY;
		}
	}
	$_screen->set_deferred_refresh(R_LISTING);
}

sub handlefind_incremental {
	my ($self) = @_;
	my ($findme, $key, $screenline);
	my $prompt = 'File to find: ';
	my $cursorjumptime = .5;
	my $cursorcol = $_screen->listing->cursorcol;
	$_screen->clear_footer();
	FINDINCENTRY:
	while (1) {
		$_screen
			->listing->highlight_on()
			->at(0,0)->clreol()->putmessage($prompt)
			->puts($findme);
		if ($cursorjumptime) {
			$screenline = $_pfm->browser->currentline + $_screen->BASELINE;
			while (!$_screen->key_pressed($cursorjumptime)) {
				$_screen->at($screenline, $cursorcol);
				last if ($_screen->key_pressed($cursorjumptime));
				$_screen->at(0, length($prompt) + length $findme);
			}
		}
		$key = $_screen->getch();
		$_screen->listing->highlight_off();
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
		$_screen->listing->show();
	}
	$_screen->set_deferred_refresh(R_MENU);
}

=item handleedit()

Starts the editor for editing the current fileZ<>(s) (B<E>dit command).

=cut

sub handleedit {
	my ($self) = @_;
	my $do_this;
	$_screen->alternate_off()->clrscr()->at(0,0)->cooked_echo();
	$do_this = sub {
		my $file = shift;
		system $_pfm->config->{editor}." \Q$file->{name}\E"
			and $_screen->display_error('Editor failed');
	};
	$_pfm->state->directory->apply($do_this);
	$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$_screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handlechown()

Handles changing the owner of a file (B<U>ser command).

=cut

sub handlechown {
	my ($self) = @_;
	my ($newuid, $do_this);
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('U');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newuid = $_pfm->history->input({
		history => H_MODE,
		prompt  => 'New [user][:group] ',
	}));
	$_screen->raw_noecho();
	return if ($newuid eq '');
	$do_this = sub {
		my $file = shift;
		if (system('chown', $newuid, $file->{name})) {
			$_screen->neat_error('Change owner failed');
		}
	};
	$_pfm->state->directory->apply($do_this);
	# re-sort
	if ($_pfm->state->sort_mode =~ /[ug]/i and
		$_pfm->config->{autosort})
	{
		$_screen->set_deferred_refresh(R_LISTING);
		# 2.06.4: sortcontents() doesn't sort @showncontents.
		# therefore, apply the filter again as well.
		$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
		# TODO fire 'save_cursor_position'
		$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
	}
}

=item handlechmod()

Handles changing the mode (permission bits) of a file (B<A>ttribute command).

=cut

sub handlechmod {
	my ($self) = @_;
	my ($newmode, $do_this);
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('A');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newmode = $_pfm->history->input({
		history => H_MODE,
		prompt  => 'New mode [ugoa][-=+][rwxslt] or octal: ',
	}));
	$_screen->raw_noecho();
	return if ($newmode eq '');
	if ($newmode =~ s/^\s*(\d+)\s*$/oct($1)/e) {
		$do_this = sub {
			my $file = shift;
			unless (chmod $newmode, $file->{name}) {
				$_screen->neat_error($!);
			}
		};
	} else {
		$do_this = sub {
			my $file = shift;
			if (system 'chmod', $newmode, $file->{name}) {
				$_screen->neat_error('Change mode failed');
			}
		};
	}
	$_pfm->state->directory->apply($do_this);
}

=item handletime()

Handles changing the timestamp of a file (B<T>ime command).

=cut

sub handletime {
	my ($self) = @_;
	my ($newtime, $do_this, @cmdopts);
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('T');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	$newtime = $_pfm->history->input({
		history       => H_TIME,
		prompt        => 'Timestamp [[CC]YY-]MM-DD hh:mm[.ss]: ',
		history_input => strftime ("%Y-%m-%d %H:%M.%S", localtime time),
	});
	$_screen->raw_noecho();
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
			$_screen->neat_error('Set timestamp failed');
		}
	};
	$_pfm->state->directory->apply($do_this);
	# re-sort
	if ($_pfm->state->sort_mode =~ /[da]/i and
		$_pfm->config->{autosort})
	{
		$_screen->set_deferred_refresh(R_LISTING);
		# 2.06.4: sortcontents() doesn't sort @showncontents.
		# therefore, apply the filter again as well.
		$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
		# TODO fire 'save_cursor_position'
		$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
	}
}

=item handleshow()

Handles displaying the contents of a file (B<S>how command).

=cut

sub handleshow {
	my ($self) = @_;
	my ($do_this);
	if ($self->_followmode($_pfm->browser->currentfile) =~ /^d/) {
		goto &handleentry;
	}
	$_screen->clrscr()->at(0,0)->cooked_echo();
	$do_this = sub {
		my $file = shift;
		$_screen->puts($file->{name} . "\n")
			->alternate_off();
		system $_pfm->config->{pager}." \Q$file->{name}\E"
			and $_screen->display_error("Pager failed\n");
		$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	};
	$_pfm->state->directory->apply($do_this);
	$_screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handleunwo()

Handles removing a whiteout file (unB<W>hiteout command).

=cut

sub handleunwo {
	my ($self) = @_;
	my ($do_this);
	my $nowhiteouterror = 'Current file is not a whiteout';
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU);
		$_screen->listing->markcurrentline('W');
	}
	if (!$_pfm->state->{multiple_mode} and
		$_pfm->browser->currentfile->{type} ne 'w')
	{
		$_screen->at(0,0)->clreol()->display_error($nowhiteouterror);
		return;
	}
	$_screen->at($_screen->PATHLINE,0);
	$do_this = sub {
		my $file = shift;
		if ($file->{type} eq 'w') {
			if ($_pfm->os->unwo($file->{name})) {
				$_screen->neat_error('Whiteout removal failed');
			}
		} else {
			$_screen->neat_error($nowhiteouterror);
		}
	};
	$_pfm->state->directory->apply($do_this);
}

=item handleversion()

Checks if the current directory is under version control,
and starts a job for the file if so (B<V>ersion command).

=cut

sub handleversion {
	my ($self) = @_;
	if ($_pfm->state->{multiple_mode}) {
		$_pfm->state->directory->apply(sub {});
		$_pfm->state->directory->checkrcsapplicable();
		$_screen->set_deferred_refresh(R_LISTING | R_MENU);
	} else {
		$_pfm->state->directory->checkrcsapplicable(
			$_pfm->browser->currentfile->{name});
	}
}

=item handleinclude(char $key)

Handles including (marking) and excluding (unmarking) files
(B<I>nclude and eB<X>clude commands).

=cut

sub handleinclude { # include/exclude flag (from keypress)
	my ($self, $exin) = @_;
	my $directory    = $_pfm->state->directory;
	my $printline    = $_screen->BASELINE;
	my $infocol      = $_screen->diskinfo->infocol;
	my %inc_criteria = @{INC_CRITERIA()};
	my ($criterion, $menulength, $key, $wildfilename, $entry, $i,
		$boundarytime, $boundarysize);
	$exin = lc $exin;
	$_screen->diskinfo->clearcolumn();
	# we can't use foreach (keys %mark_criteria) because we would lose ordering
	foreach (grep { ($i += 1) %= 2 } @{INC_CRITERIA()}) { # keep keys, skip values
		last if ($printline > $_screen->BASELINE + $_screen->screenheight);
		$_screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s', $_, $inc_criteria{$_}));
	}
	my $menu_mode = $exin eq 'x' ? MENU_EXCLUDE : MENU_INCLUDE;
	$menulength = $_screen
		->set_deferred_refresh(R_FRAME | R_PATHINFO | R_DISKINFO)
		->show_frame({
			menu     => $menu_mode,
			footer   => FOOTER_NONE,
			headings => HEADING_CRITERIA
		});
	$key = lc $_screen->at(0, $menulength+1)->getch();
	if      ($key eq 'o') { # oldmarks
		$criterion = sub { my $file = shift; $file->{selected} eq M_OLDMARK };
	} elsif ($key eq 'n') { # newmarks
		$criterion = sub { my $file = shift; $file->{selected} eq M_NEWMARK };
	} elsif ($key eq 'e') { # every
		$criterion = sub { my $file = shift; $file->{name} !~ /^\.\.?$/ };
	} elsif ($key eq 'u') { # user only
		$criterion = sub { my $file = shift; $file->{uid} eq $ENV{USER} };
	} elsif ($key =~ /^[gs]$/) { # greater/smaller
		if ($boundarysize = $self->_promptforboundarysize($key)) {
			if ($key eq 'g') {
				$criterion = sub {
					my $file = shift;
					$file->{size} >= $boundarysize and
					$file->{name} !~ /^\.\.?$/;
				};
			} else {
				$criterion = sub {
					my $file = shift;
					$file->{size} <= $boundarysize and
					$file->{name} !~ /^\.\.?$/;
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
				$_screen->set_deferred_refresh(R_SCREEN);
			}
		}
	}
}

=item handlesize()

Handles reporting the size of a file, or of a directory and
subdirectories (siB<Z>e command).

=cut

sub handlesize {
	my ($self) = @_;
	my ($do_this);
	my $filerecordcol = $_screen->listing->filerecordcol;
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_SCREEN);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('Z');
	}
	$do_this = sub {
		my $file = shift;
		my ($recursivesize, $command, $tempfile, $res);
		$recursivesize = $_pfm->os->du($file->{name});
		$recursivesize =~ s/^\D*(\d+).*/$1/;
		chomp $recursivesize;
		# if a CHLD signal handler is installed, $? is not always reliable.
		if ($?) {
			$_screen->at(0,0)->clreol()
				->putmessage('Could not read all directories')
				->set_deferred_refresh(R_SCREEN);
			$recursivesize ||= 0;
		}
		@{$file}{qw(grand grand_num grand_power)} =
			($recursivesize, fit2limit(
				$recursivesize, $_screen->listing->maxgrandtotallength));
		if (join('', @{$_screen->listing->layoutfields}) !~ /grand/ and
			!$_pfm->state->{multiple_mode})
		{
			my $screenline = $_pfm->browser->currentline + $_screen->BASELINE;
			# use filesize field of a cloned object.
			$tempfile = $file->clone();
			@{$tempfile}{qw(size size_num size_power)} =
				($recursivesize, fit2limit(
					$recursivesize, $_screen->listing->maxfilesizelength));
			$_screen->at($screenline, $filerecordcol)
				->puts($_screen->listing->fileline($tempfile))
				->listing->markcurrentline('Z')
				->listing->applycolor($screenline,
					$_screen->listing->FILENAME_SHORT, $tempfile);
			$_screen->getch();
		}
		return $file;
	};
	$_pfm->state->directory->apply($do_this, 'norestat');
}

=item handletarget()

Changes the target of a symbolic link (tarB<G>et command).

=cut

sub handletarget {
	my ($self) = @_;
	my ($newtarget, $do_this);
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('G');
	}
	my $nosymlinkerror = 'Current file is not a symbolic link';
	if ($_pfm->browser->currentfile->{type} ne 'l' and
		!$_pfm->state->{multiple_mode})
	{
		$_screen->at(0,0)->clreol()->display_error($nosymlinkerror);
		return;
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newtarget = $_pfm->history->input({
		history       => H_PATH,
		prompt        => 'New symlink target: ',
		history_input => $_pfm->browser->currentfile->{target},
	}));
	$_screen->raw_noecho();
	return if ($newtarget eq '');
	$do_this = sub {
		my $file = shift;
		my ($newtargetexpanded, $oldtargetok);
		if ($file->{type} ne 'l') {
			$_screen->at(0,0)->clreol()->display_error($nosymlinkerror);
		} else {
			# $self is the commandhandler (closure!)
			$self->_expand_escapes(
				$self->QUOTE_OFF, ($newtargetexpanded = $newtarget), $file);
			$oldtargetok = 1;
			if (-d $file->{name}) {
				# if it points to a dir, the symlink must be removed first
				# next line is an intentional assignment
				unless ($oldtargetok = unlink $file->{name}) {
					$_screen->neat_error($!);
				}
			}
			if ($oldtargetok and
				system qw(ln -sf), $newtargetexpanded, $file->{name})
			{
				$_screen->neat_error('Replace symlink failed');
			}
		}
	};
	$_pfm->state->directory->apply($do_this);
}

=item handlecommand(char $key)

Executes a shell command (cB<O>mmand and B<Y>our-command).

=cut

sub handlecommand { # Y or O
	my ($self, $key) = @_;
	my $printline  = $_screen->BASELINE;
	my $infocol    = $_screen->diskinfo->infocol;
	my $infolength = $_screen->diskinfo->infolength;
	my $e          = $_pfm->config->{e};
	my ($command, $do_this, $prompt, $printstr, $newdir);
	unless ($_pfm->state->{multiple_mode}) {
		$_screen->listing->markcurrentline(uc $key);
	}
	$_screen->diskinfo->clearcolumn();
	if (uc($key) eq 'Y') { # Your command
		$prompt = 'Enter one of the highlighted characters below: ';
		foreach (sort alphabetically $_pfm->config->your_commands) {
			last if ($printline > $_screen->BASELINE + $_screen->screenheight);
			$printstr = $_pfm->config->pfmrc()->{$_};
			$printstr =~ s/\e/^[/g; # in case real escapes are used
			$_screen->at($printline++, $infocol)
				->puts(sprintf('%1s %s',
						substr($_,5,1),
						substr($printstr,0,$infolength-2)));
		}
		$_screen->show_frame({
			headings => HEADING_YCOMMAND,
			footer   => FOOTER_NONE,
			prompt   => $prompt,
		});
		$key = $_screen->getch();
		$_screen->diskinfo->clearcolumn()
			->set_deferred_refresh(R_DISKINFO | R_FRAME);
		# next line contains an assignment on purpose
		return unless $command = $_pfm->config->pfmrc()->{"your[$key]"};
		$_screen->cooked_echo();
	} else { # cOmmand
		$prompt =
			"Enter Unix command ($e"."[1-8] or $e"."[epv] escapes see below):";
		foreach (sort escape_midway keys %{CMDESCAPES()}, $e) {
			if ($printline <= $_screen->BASELINE + $_screen->screenheight) {
				$_screen->at($printline++, $infocol)
					->puts(sprintf(' %1s%1s %s', $e, $_,
							${CMDESCAPES()}{$_} || "literal $e"));
			}
		}
		$_screen->show_frame({
			menu     => MENU_NONE,
			footer   => FOOTER_NONE,
			headings => HEADING_ESCAPE,
		});
		$_screen->set_deferred_refresh(R_DISKINFO);
		$_screen->at(0,0)->clreol()->putmessage($prompt)
			->at($_screen->PATHLINE,0)->clreol()
			->cooked_echo();
		$command = $_pfm->history->input({
			history => H_COMMAND,
			prompt  => ''
		});
		$_screen->diskinfo->clearcolumn();
	}
	# chdir special case
	if ($command =~ /^\s*cd\s(.*)$/) {
		$newdir = $1;
		$self->_expand_escapes(QUOTE_OFF, $newdir, $_pfm->browser->currentfile);
		$_screen->raw_noecho();
		if (!$_screen->ok_to_remove_marks()) {
			$_screen->set_deferred_refresh(R_MENU); # R_SCREEN?
			return;
		} elsif (!$_pfm->state->directory->chdir($newdir)) {
			$_screen->at(2,0)->display_error("$newdir: $!")
				->set_deferred_refresh(R_SCREEN);
			return;
		}
		$_screen->set_deferred_refresh(R_CHDIR);
		return;
	}
	# general case: command (either Y or O) is known here
	if ($command !~ /\S/) {
		$_screen->raw_noecho()->set_deferred_refresh(R_MENU | R_PATHINFO);
		return
	}
	$_screen->alternate_off()->clrscr()->at(0,0);
	$do_this = sub {
		my $file = shift;
		my $do_command = $command;
		# $self is the commandhandler (closure!)
		$self->_expand_escapes($self->QUOTE_ON, $do_command, $file);
		$_screen->puts("\n$do_command\n");
		system $do_command
			and $_screen->display_error("External command failed\n");
	};
	$_pfm->state->directory->apply($do_this, 'nofeedback');
	$_screen->pressanykey();
	$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$_screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handleprint()

Executes a print command (B<P>print).

=cut

sub handleprint {
	my ($self) = @_;
	my ($do_this, $command);
	my $printcmd = $_pfm->config->{printcmd};
	if (!$_pfm->state->{multiple_mode}) {
		$_screen->listing->markcurrentline('P');
	}
	$_screen->show_frame({
		footer => FOOTER_NONE,
		prompt => 'Enter print command: ',
	});
	$_screen->at($_screen->PATHLINE, 0)->clreol()
		->cooked_echo();
	$command = $_pfm->history->input({
		history       => H_COMMAND,
		prompt        => '',
		default_input => $printcmd,
		pushfilter    => $printcmd,
	});
	$_screen->raw_noecho();
	if ($command eq '') {
		$_screen->set_deferred_refresh(R_FRAME | R_DISKINFO | R_PATHINFO);
		return;
	}
	#$_screen->alternate_off()->clrscr()->at(0,0);
	$do_this = sub {
		my $file = shift;
		my $do_command = $command;
		$self->_expand_escapes($self->QUOTE_ON, $do_command, $file);
		$_screen->puts("\n$do_command\n");
		system $do_command
			and $_screen->display_error("Print command failed\n");
	};
	# we could supply 'O' in the next line to treat it like a real cOmmand
	$_pfm->state->directory->apply($do_this);
	#$_screen->pressanykey();
	#$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$_screen->set_deferred_refresh(R_SCREEN);
	return;
}

=item handledelete()

Handles deleting files (B<D>elete command).

=cut

sub handledelete {
	my ($self) = @_;
	my ($do_this, $sure, $oldpos);
	my $browser    = $_pfm->browser;
	my $directory  = $_pfm->state->directory;
	unless ($_pfm->state->{multiple_mode}) {
		$_screen->listing->markcurrentline('D');
	}
	if ($_pfm->state->{multiple_mode} or $browser->currentfile->{nlink}) {
		$_screen->set_deferred_refresh(R_MENU | R_FOOTER)
			->show_frame({
				footer => FOOTER_NONE,
				prompt => 'Are you sure you want to delete [Y/N]? ',
			});
		$sure = $_screen->getch();
		return if $sure !~ /y/i;
	}
	$_screen->at($_screen->PATHLINE, 0)
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
				$_screen->at(0,0)->clreol()->putmessage(
					'Recursively delete a non-empty directory ',
					'[Affirmative/Negative]? ');
				$sure = lc $_screen->getch();
				$_screen->at(0,0);
				if ($sure eq 'a') {
					$success = !system('rm', '-rf', $file->{name});
				} else {
					$msg = 'Deletion cancelled. Directory not empty';
					$success = 0;
				}
				$_screen->clreol();
			}
		} else {
			$success = unlink $file->{name};
		}
		if (!$success) {
			$_screen->display_error($msg || $!);
		}
		return $success ? 'deleted' : '';
	};
	$oldpos = $browser->currentfile->{name};
	$directory->apply($do_this, 'delete');
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

=item handlecopyrename(char $key)

Handles copying and renaming files (B<C>opy and B<R>ename).

=cut

sub handlecopyrename {
	my ($self, $key) = @_;
	$key = uc $key;
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
		$_screen->set_deferred_refresh(R_MENU | R_FOOTER | R_LISTING);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_FOOTER);
		$_screen->listing->markcurrentline($key);
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	my $history_input =
		$state->{multiple_mode} ? undef : $browser->currentfile->{name};
	$newname = $_pfm->history->input({
		history       => H_PATH,
		prompt        => $prompt,
		history_input => $history_input,
	});
	$_screen->raw_noecho();
	return if ($newname eq '');
	# expand =[3456] at this point as a test, but not =[1278]
	$self->_expand_3456_escapes(QUOTE_OFF, ($testname = $newname));
	return if $self->_multi_to_single($testname);
	$_screen->at(1,0)->clreol() unless $self->{_clobber_mode};
	$do_this = sub {
		my $file = shift;
		my $findindex;
		# move this outsde of do_this
#		if ($key eq 'C' and $file->{type} =~ /[ld]/ ) {
#			# AIX: cp -r follows symlink
#			# Linux: cp -r copies symlink
#			$_screen->at(0,0)->clreol();
#				->putmessage('Copy symlinks to symlinks [Copy/Follow]? ');
#			$sure = lc $_screen->getch();
#			$_screen->at(0,0);
#			if ($sure eq 'c') {
#			} else {
#			}
#			$_screen->clreol();
#		} elsif
		# $self is the commandhandler (closure!)
		$self->_expand_escapes(
			QUOTE_OFF, ($newnameexpanded = $newname), $file);
		if (system @command, $file->{name}, $newnameexpanded) {
			$_screen->neat_error($key eq 'C' ? 'Copy failed' : 'Rename failed');
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
	$_screen->cooked_echo() unless $self->{_clobber_mode};
	$state->directory->apply($do_this);
	# if ! $clobber_mode, we might have gotten an 'Overwrite?' question
	unless ($self->{_clobber_mode}) {
		$_screen->set_deferred_refresh(R_SCREEN);
		$_screen->raw_noecho();
	}
	return;
}

=item handleopenwindow(App::PFM::File $file)

Opens a new terminal window running pfm.

=cut

sub handleopenwindow {
	my ($self, $file) = @_;
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
	my ($prevcurrentline, $on_name, $currentfile);
	my $browser  = $_pfm->browser;
	my $listing  = $_screen->listing;
	my $mbutton  = $event->{mousebutton};
	my $mousecol = $event->{mousecol};
	my $mouserow = $event->{mouserow};
	# button ---------------- location clicked ------------------------
	#       pathline  menu/footer  heading   fileline  filename dirname
	# 1     chdir()   (command)    sort      F8        Show     Show
	# 2     cOmmand   (command)    sort rev  Show      ENTER    new win
	# 3     cOmmand   (command)    sort rev  Show      ENTER    new win
	# -----------------------------------------------------------------
	if ($mouserow == $_screen->PATHLINE) {
		# path line
		if ($mbutton) {
			$self->handlecommand('o');
		} else {
			$self->handlemousepathjump($mousecol);
		}
	} elsif ($mouserow == $_screen->HEADINGLINE) {
		# headings
		$self->handlemouseheadingsort($mousecol, $mbutton);
	} elsif ($mouserow == 0) {
		# menu
		# return the return value as this could be 'quit'
		return $self->handlemousemenucommand($mousecol);
	} elsif ($mouserow > $_screen->screenheight + $_screen->BASELINE) {
		# footer
		$self->handlemousefootercommand($mousecol);
	} elsif (($mousecol <  $listing->filerecordcol)
		or	($mousecol >= $_screen->diskinfo->infocol
		and	$_screen->diskinfo->infocol > $listing->filerecordcol))
	{
		$self->handleident() if $mouserow == $_screen->diskinfo->LINE_USERINFO;
	} elsif (defined ${$_pfm->state->directory->showncontents}[
		$mouserow - $_screen->BASELINE + $_pfm->browser->baseindex])
	{
		# clicked on an existing file
		# save currentline
		$prevcurrentline   = $_pfm->browser->currentline;
		# put cursor temporarily on another file
		$_pfm->browser->currentline($mouserow - $_screen->BASELINE);
		$on_name = (
			$mousecol >= $listing->filenamecol and
			$mousecol <= $listing->filenamecol + $listing->maxfilenamelength);
		if ($on_name and $mbutton) {
			$currentfile = $_pfm->browser->currentfile;
			if ($currentfile->{type} eq 'd') {
				$self->handleopenwindow($currentfile);
			} else {
				$self->handleenter();
			}
		} elsif (!$on_name and !$mbutton) {
			$self->handlemark();
		} else {
			$self->handleshow();
		}
		# restore currentline
		# note that if we changed directory, there will be a position_at anyway
		$_pfm->browser->currentline($prevcurrentline);
	}
	return 1; # must return true to fill $valid in sub handle()
}

=item handlemousepathjump(int $mouse_column)

Handles a click in the directory path, and changes to this directory.
The parameter I<mouse_column> indicates where the mouse was clicked.

=cut

sub handlemousepathjump {
	my ($self, $mousecol) = @_;
	my ($baselen, $skipsize, $selecteddir);
	my $currentdir = $_pfm->state->directory->path;
	my $pathline = $_screen->pathline(
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
	} elsif ($_screen->ok_to_remove_marks()) {
		if (!$_pfm->state->directory->chdir($selecteddir)) {
			$_screen->display_error("$selecteddir: $!");
			$_screen->set_deferred_refresh(R_SCREEN);
		}
	}
}

=item handlemouseheadingsort(int $mouse_column, int $mouse_button)

Sorts the directory contents according to the heading clicked.

=cut

sub handlemouseheadingsort {
	my ($self, $mousecol, $mbutton) = @_;
	my $currentlayoutline = $_screen->listing->currentlayoutline;
	my %sortmodes = @{FIELDS_TO_SORTMODE()};
	# get field character
	my $key = substr($currentlayoutline, $mousecol, 1);
#	if ($key eq '*') {
#		goto &handlemarkall;
#	}
	# translate field character to sort mode character
	$key = $sortmodes{$key};
	if ($key) {
		$key = uc($key) if $mbutton;
		# we don't need locale-awareness here
		$key =~ tr/A-Za-z/a-zA-Z/ if ($_pfm->state->sort_mode eq $key);
		$_pfm->state->sort_mode($key);
		$_pfm->browser->position_at(
			$_pfm->browser->currentfile->{name}, { force => 0, exact => 1 });
	}
	$_screen->set_deferred_refresh(R_SCREEN);
	$_pfm->state->directory->set_dirty(D_SORT | D_FILTER);
}

=item handlemousemenucommand(int $mouse_column)

Starts the menu command that was clicked on.

=cut

sub handlemousemenucommand {
	my ($self, $mousecol) = @_;
	my $vscreenwidth = $_screen->screenwidth - 9* $_pfm->state->{multiple_mode};
	# hack: add 'Multiple' marker
	my $M     = "0";
	my $menu  = ($_pfm->state->{multiple_mode} ? "${M}ultiple " : '') .
						$_screen->frame->_fitbanner(
							$_screen->frame->_getmenu(), $vscreenwidth);
	my $left  = $mousecol - 1;
	my $right = $_screen->screenwidth - $mousecol - 1;
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
	#$_screen->at(1,0)->puts("L-$left :$choice: R-$right    ");
	return $self->handle(new App::PFM::Event({
		name   => 'after_receive_non_motion_input',
		type   => 'key',
		origin => $self,
		data   => $choice,
	}));
}

=item handlemousefootercommand(int $mouse_column)

Starts the footer command that was clicked on.

=cut

sub handlemousefootercommand {
	my ($self, $mousecol) = @_;
	my $menu  = $_screen->frame->_fitbanner(
					$_screen->frame->_getfooter(), $_screen->screenwidth);
	my $left  = $mousecol - 1;
	my $right = $_screen->screenwidth - $mousecol - 1;
	my $choice;
	$menu =~ /^					# anchor
		(?:.{0,$left}\s|)		# (empty string left  || chars then space)
		(?:						#
			(\W-				# non-alphabetic
			|F\d+-				# or F<digits>
			|[<>]				# or pan character
			)					#
			\S*					# any nr. of non-space chars
		)						#
		(?:\s.{0,$right}|)		# (empty string right || space then chars)
		$/x;					# anchor
	($choice = $1)	=~ s/-$//;	# transform F12- to F12
	$choice			=~ s/^F/k/;	# transform F12  to k12
	#$_screen->at(1,0)->puts("L-$left :$choice: R-$right    ");
	return $self->handlecyclesort() if ($choice eq 'k6');
	return $self->handle(new App::PFM::Event({
		name   => 'after_receive_non_motion_input',
		type   => 'key',
		origin => $self,
		data   => $choice,
	}));
}

=item handlemore()

Shows the menu of B<M>ore commands, and handles the user's choice.

=cut

sub handlemore {
	my ($self) = @_;
	my $frame  = $_screen->frame;
	my $oldpan = $frame->currentpan();
	$frame->currentpan(0);
	my $key;
#	$_screen->clear_footer()->noecho()
#		->set_deferred_refresh(R_MENU);
	my $headerlength = $_screen->noecho()->set_deferred_refresh(R_MENU)
		->show_frame({
			footer => FOOTER_MORE,
			menu   => MENU_MORE,
		});
	MORE_PAN: {
		$key = $_screen->at(0, $headerlength+1)->getch();
		for ($key) {
			/^s$/io		and $self->handlemoreshow(),		last MORE_PAN;
			/^m$/io		and $self->handlemoremake(),		last MORE_PAN;
			/^c$/io		and $self->handlemoreconfig(),		last MORE_PAN;
			/^e$/io		and $self->handlemoreedit(),		last MORE_PAN;
			/^h$/io		and $self->handlemoreshell(),		last MORE_PAN;
			/^a$/io		and $self->handlemoreacl(),			last MORE_PAN;
			/^b$/io		and $self->handlemorebookmark(),	last MORE_PAN;
			/^g$/io		and $self->handlemorego(),			last MORE_PAN;
			/^f$/io		and $self->handlemorefifo(),		last MORE_PAN;
			/^w$/io		and $self->handlemorehistwrite(),	last MORE_PAN;
			/^t$/io		and $self->handlemorealtscreen(),	last MORE_PAN;
			/^p$/io		and $self->handlemorephyspath(),	last MORE_PAN;
			/^v$/io		and $self->handlemoreversion(),		last MORE_PAN;
			/^k6$/io	and $self->handlemoremultisort(),	last MORE_PAN;
			/^[<>]$/io	and do {
				$self->handlepan($_, MENU_MORE);
				$headerlength = $frame->show_menu(MENU_MORE);
				$frame->show_footer(FOOTER_MORE);
				redo MORE_PAN;
			};
		}
	}
	$frame->currentpan($oldpan);
}

=item handlemoreshow()

Does a chdir() to any directory (B<M>ore - B<S>how).

=cut

sub handlemoreshow {
	my ($self) = @_;
	my ($newname);
	$_screen->set_deferred_refresh(R_MENU);
	return if !$_screen->ok_to_remove_marks();
	$_screen->at(0,0)->clreol()->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'Directory Pathname: ',
	});
	$_screen->raw_noecho();
	return if $newname eq '';
	$self->_expand_escapes(QUOTE_OFF, $newname, $_pfm->browser->currentfile);
	if (!$_pfm->state->directory->chdir($newname)) {
		$_screen->set_deferred_refresh(R_PATHINFO)
			->display_error("$newname: $!");
	}
}

=item handlemoremake()

Makes a new directory (B<M>ore - B<M>ake).

=cut

sub handlemoremake {
	my ($self) = @_;
	my ($newname);
	$_screen->set_deferred_refresh(R_MENU);
	$_screen->at(0,0)->clreol()->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'New Directory Pathname: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $_pfm->browser->currentfile);
	$_screen->raw_noecho();
	return if $newname eq '';
	# don't use perl's mkdir: we want to be able to use -p
	if (system "mkdir -p \Q$newname\E") {
		$_screen->set_deferred_refresh(R_SCREEN)
			->at(0,0)->clreol()->display_error('Make directory failed');
	} elsif (!$_screen->ok_to_remove_marks()) {
		if ($newname !~ m!/!) {
			$_pfm->state->directory->addifabsent(
				entry => $newname,
				mark => ' ',
				white => '',
				refresh => TRUE);
			$_pfm->browser->position_at($newname);
		}
	} elsif (!$_pfm->state->directory->chdir($newname)) {
		$_screen->at(0,0)->clreol()->display_error("$newname: $!");
	}
}

=item handlemoreconfig()

Opens the current config file (F<.pfmrc>) in the configured editor
(B<M>ore - B<C>onfig).

=cut

sub handlemoreconfig {
	my ($self) = @_;
	my $config        = $_pfm->config;
	my $olddotdot     = $config->{dotdot_mode};
	my $config_editor = $config->{fg_editor} || $config->{editor};
	$_screen->at(0,0)->clreol()
		->set_deferred_refresh(R_CLRSCR);
	if (system $config_editor, $config->location()) {
		$_screen->at(1,0)->display_error('Editor failed');
	} else {
		$config->read( $config->READ_AGAIN);
		$config->parse($config->NO_COPYRIGHT);
		$config->apply();
		if ($olddotdot != $config->{dotdot_mode}) {
			# there is no key to toggle dotdot mode, therefore
			# it is allowed to switch dotdot mode here.
			$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
			$_pfm->state->directory->set_dirty(D_SORT);
		}
	}
}

=item handlemoreedit()

Opens any file in the configured editor (B<M>ore - B<E>dit).

=cut

sub handlemoreedit {
	my ($self) = @_;
	my $newname;
	$_screen->at(0,0)->clreol()->cooked_echo()
		->set_deferred_refresh(R_CLRSCR);
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'Filename to edit: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $_pfm->browser->currentfile);
	if (system $_pfm->config->{editor}." \Q$newname\E") {
		$_screen->display_error('Editor failed');
	}
	$_screen->raw_noecho();
}

=item handlemoreshell()

Starts the user's login shell (B<M>ore - sB<H>ell).

=cut

sub handlemoreshell {
	my ($self) = @_;
	my $chdirautocmd = $_pfm->config->{chdirautocmd};
	$_screen->alternate_off()->clrscr()->cooked_echo()
		->set_deferred_refresh(R_CLRSCR);
#	@ENV{qw(ROWS COLUMNS)} = ($screenheight + $BASELINE + 2, $screenwidth);
	system ($ENV{SHELL} ? $ENV{SHELL} : 'sh'); # most portable
	$_screen->pressanykey(); # will also put the screen back in raw mode
	$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	system("$chdirautocmd") if length($chdirautocmd);
}

=item handlemoreacl()

Allows the user to edit the file's Access Control List (B<M>ore - B<A>cl).

=cut

sub handlemoreacl {
    my ($self) = @_;
	# we count on the OS-specific command to start an editor.
	$_screen->alternate_off()->clrscr()->at(0,0)->cooked_echo();
	my $do_this = sub {
		my $file = shift;
		unless ($_pfm->os->acledit($file->{name})) {
			$_screen->neat_error($!);
		}
	};
	$_pfm->state->directory->apply($do_this);
	$_screen->pressanykey();
	$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	$_screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handlemorebookmark()

Creates a bookmark to the current directory (B<M>ore - B<B>ookmark).

=cut

sub handlemorebookmark {
	my ($self) = @_;
	my $browser   = $_pfm->browser;
	my ($dest, $key, $prompt);# , $destfile
	# the footer has already been cleared by handlemore()
	# choice
	$self->_listbookmarks();
	$_screen->show_frame({
		headings => HEADING_BOOKMARKS,
		footer   => FOOTER_NONE,
		prompt   => 'Bookmark under which letter? ',
	});
	$key = $_screen->getch();
	return if $key eq "\r";
	# process key
	if ($key !~ /^[a-zA-Z]$/) {
		# the bookmark is undefined
		$_screen->at(0,0)->clreol()
				->display_error('Bookmark name not valid');
		return;
	}
	$_pfm->state->{_position}  = $browser->currentfile->{name};
	$_pfm->state->{_baseindex} = $browser->baseindex;
	$_pfm->state($key, $_pfm->state->clone());
}

=item handlemorego()

Shows a list of the current bookmarks, then offers the user a choice to
jump to one of them (B<M>ore - B<G>o).

=cut

sub handlemorego {
	my ($self) = @_;
	my $browser   = $_pfm->browser;
	my ($dest, $key, $prompt, $destfile, $success,
		$prevdir, $prevstate, $chdirautocmd);
	# the footer has already been cleared by handlemore()
	$self->_listbookmarks();
	# choice
	$prompt = 'Go to which bookmark? ';
	$key = $_screen->at(0,0)->clreol()
		->putmessage($prompt)->getch();
	return if $key eq "\r";
	$dest = $_pfm->state($key);
	if ($dest eq '') {
		# the bookmark is undefined
		$_screen->at(0,0)->clreol()
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
			$_screen->set_deferred_refresh(R_SCREEN);
		} elsif (!$success) {
			# the state needs refreshing as we counted on being
			# able to chdir()
			$_screen->at($_screen->PATHLINE, 0)->clreol()
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
			$_screen->set_deferred_refresh(R_PATHINFO)
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

=item handlemorefifo()

Handles creating a FIFO (named pipe) (B<M>ore - mkB<F>ifo).

=cut

sub handlemorefifo {
	my ($self) = @_;
	my ($newname, $findindex);
	$_screen->at(0,0)->clreol()
		->set_deferred_refresh(R_MENU)
		->cooked_echo();
	$newname = $_pfm->history->input({
		history => H_PATH,
		prompt  => 'New FIFO name: ',
	});
	$self->_expand_escapes(QUOTE_OFF, $newname, $_pfm->browser->currentfile);
	$_screen->raw_noecho();
	return if $newname eq '';
	$_screen->set_deferred_refresh(R_SCREEN);
	if (system "mkfifo \Q$newname\E") {
		$_screen->display_error('Make FIFO failed');
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
	$_screen->set_deferred_refresh(R_CLRSCR)
		->alternate_off()->pressanykey();
}

=item handlemorephyspath()

Shows the canonical pathname of the current directory (B<M>ore - B<P>hysical).

=cut

sub handlemorephyspath {
	my ($self) = @_;
#	$_screen->frame->show_menu(); # this was added for some reason in pfm1; why?
	$_screen->at(0,0)->clreol()
		->putmessage('Current physical path:')
		->path_info($_screen->PATH_PHYSICAL)
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

=item handlemoremultisort()

Handles asking for user input and setting multilevel sort mode.

=cut

sub handlemoremultisort {
	my ($self) = @_;
	$self->handlesort(TRUE);
}

=item handleenter()

Enter a directory or launch a file (B<ENTER>).

=cut

sub handleenter {
	my ($self) = @_;
	my $directory   = $_pfm->state->directory;
	my $currentfile = $_pfm->browser->currentfile;
	my $pfmrc       = $_pfm->config->pfmrc;
	my $do_this;
	if ($self->_followmode($currentfile) =~ /^d/) {
		goto &handleentry;
	}
	$_screen->at(0,0)->clreol()->at(0,0)->cooked_echo()
		->alternate_off();
	LAUNCH: foreach (split /,/, $_pfm->config->{launchby}) {
		# these functions return either:
		# - a code reference to be used in Directory->apply()
		# - a falsy value if no applicable launch command can be found
		/magic/     and $do_this = $self->launchbymagic();
		/extension/ and $do_this = $self->launchbyextension();
		/xbit/      and $do_this = $self->launchbyxbit();
		# continue trying until one of the modes finds a launch command
		last LAUNCH if $do_this;
	}
	if (ref $do_this) {
		# a code reference: possible way to launch
		$currentfile->apply($do_this);
		$_screen->set_deferred_refresh(R_CLRSCR)->pressanykey();
	} elsif (defined $do_this) {
		# an error message: the file type was unknown.
		# feed it to the pager instead.
		$_screen->clrscr();
		if (system $_pfm->config->{pager}." \Q$currentfile->{name}\E")
		{
			$_screen->display_error($!);
		}
		$_screen->set_deferred_refresh(R_CLRSCR);
	} else {
		# 'launchby' contains no valid entries
		$_screen->set_deferred_refresh(R_MENU)
			->display_error("No valid 'launchby' option in config file");
	}
	$_screen->raw_noecho();
	$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
}

=item launchbyxbit()

Returns an anonymous subroutine for executing the file if it is executable;
otherwise, returns undef.

=cut

sub launchbyxbit {
	my ($self) = @_;
	my $currentfile = $_pfm->browser->currentfile;
	my $do_this = '';
	return '' if ($self->_followmode($currentfile) !~ /[xsS]/);
	$do_this = sub {
		my $file = shift;
		$_screen->clrscr()->at(0,0)->puts("Launch executable $file->{name}\n");
		if (system "./\Q$file->{name}\E") {
			$_screen->display_error('Launch failed');
		}
	};
	return $do_this;
}

=item launchbymagic()

Determines the MIME type of a file, using its magic (see file(1)).

=cut

sub launchbymagic {
	my ($self) = @_;
	my $currentfile = $_pfm->browser->currentfile;
	my $pfmrc       = $_pfm->config->pfmrc;
	my $magic       = `file \Q$currentfile->{name}\E`;
	my $do_this     = '';
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

=item launchbyextension()

Determines the MIME type of a file by looking at its extension.

=cut

sub launchbyextension {
	my ($self) = @_;
	my $currentfile = $_pfm->browser->currentfile;
	my $pfmrc       = $_pfm->config->pfmrc;
	my ($ext)       = ( $currentfile->{name} =~ /(\.[^\.]+?)$/ );
	my $do_this     = '';
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
		$_screen->display_error("No launch command defined for type $mime\n");
		return '';
	}
	$do_this = sub {
		my $file = shift;
		my $command = $pfmrc->{"launch[$mime]"};
		$self->_expand_escapes(QUOTE_ON, $command, $file);
		$_screen->clrscr()->at(0,0)->puts("Launch type $mime\n$command\n");
		system $command and $_screen->display_error('Launch failed');
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
