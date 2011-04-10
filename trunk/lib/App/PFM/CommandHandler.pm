#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::CommandHandler 0.48
#
# Name:			App::PFM::CommandHandler
# Version:		0.48
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-30
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

use App::PFM::Util;
#use App::PFM::Application;	# imports the S_* constants
use App::PFM::History;		# imports the H_* constants
use App::PFM::Screen;		# imports the R_* constants

use POSIX qw(strftime mktime);
use Config;

use strict;

use constant {
	QUOTE_OFF    => 0,
	QUOTE_ON     => 1,
	REFRESH_HUSH => 0,
	REFRESH_ASK  => 1,
};

my %NUMFORMATS = ( 'hex' => '%#04lx', 'oct' => '%03lo');

my @SORTMODES = (
	 n =>'Name',		N =>' reverse',
	'm'=>' ignorecase',	M =>' rev+igncase',
	 e =>'Extension',	E =>' reverse',
	 f =>' ignorecase',	F =>' rev+igncase',
	 d =>'Date/mtime',	D =>' reverse',
	 a =>'date/Atime',	A =>' reverse',
	's'=>'Size',		S =>' reverse',
	'z'=>'siZe total',	Z =>' reverse',
	 t =>'Type',		T =>' reverse',
	 i =>'Inode',		I =>' reverse',
	 v =>'Version',		V =>' reverse',
);

our ($command);

my ($_pfm, $_screen,
	@_signame, $_white_cmd, @_unwo_cmd, $_clobber_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm    = $pfm;
	$_screen = $pfm->screen;
	$self->_init_signames();
	$self->_init_white_commands();
}

=item _init_signames()

Initializes the array of signal names. Called from _init().

=cut

sub _init_signames {
	my $self = shift;
	my $i = 0;
	foreach (split(/ /, $Config{sig_name})) {
		$_signame[$i++] = $_;
	}
}

=item _init_white_commands()

Finds out which commands should be used for listing and deleting whiteouts.
Called from _init().

=cut

sub _init_white_commands {
	my $self = shift;
	my $white_cmd = '';
	my @unwo_cmd  = ();
	foreach (split /:/, $ENV{PATH}) {
		if (!$white_cmd) {
			if (-f "$_/listwhite") {
				$white_cmd = 'listwhite';
			} elsif (-f "$_/lsw") {
				$white_cmd = 'lsw';
			}
		}
		if (!@unwo_cmd) {
			if (-f "$_/unwhiteout") {
				@unwo_cmd = qw(unwhiteout);
			} elsif (-f "$_/unwo") {
				@unwo_cmd = qw(unwo);
			}
		}
	}
	unless (@unwo_cmd) {
		@unwo_cmd = qw(rm -W);
	}
	$_white_cmd = $white_cmd;
	@_unwo_cmd  = @unwo_cmd;
}

=item _credits()

Prints elaborate info about pfm. Called from help().

=cut

sub _credits {
	my $self = shift;
	$_screen->clrscr()->cooked_echo();
	my $name = $_screen->colored('bold', 'pfm');
	my $version_message = $_pfm->{LATEST_VERSION}
		? "A new version $_pfm->{LATEST_VERSION} is available from"
		: "  New versions may be obtained from";
	print <<"_eoCredits_";


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


                                                         any key to exit to $name
_eoCredits_
	$_screen->raw_noecho()->getch();
}

=item _selectednames()

Creates a list of names of selected files, for the B<=8> escape.

=cut

sub _selectednames {
	my ($self, $qif) = @_;
	my $directory = $_pfm->state->directory;
	my @res =	map  {
					$directory->exclude($_, $directory->OLDMARK);
					condquotemeta($qif, $_->{name});
				}
				grep { $_->{selected} eq $directory->MARK }
				@{$directory->showncontents};
	return @res;
}

=item _expand_replace()

Creates a list of names of selected files, for the B<=8> escape.

=cut

sub _expand_replace {
	my ($self, $qif, $category, $name_no_extension, $name, $extension) = @_;
	for ($category) {
		/1/ and return condquotemeta($qif, $name_no_extension);
		/2/ and return condquotemeta($qif, $name);
		/3/ and return condquotemeta($qif, $_pfm->state->directory->path);
		/4/ and return condquotemeta($qif, $_pfm->state->directory->mountpoint);
		/5/ and $_pfm->state($_pfm->S_SWAP)
			and return condquotemeta($qif, $_pfm->state($_pfm->S_SWAP)->directory->path);
		/6/ and return condquotemeta($qif, basename($_pfm->state->directory->path));
		/7/ and return condquotemeta($qif, $extension);
		/8/ and return join (' ', $self->_selectednames($qif));
		/e/ and return condquotemeta($qif, $_pfm->config->{editor});
		/p/ and return condquotemeta($qif, $_pfm->config->{pager});
		/v/ and return condquotemeta($qif, $_pfm->config->{viewer});
		# this also handles the special $e$e case - don't quotemeta() this!
		return $_;
	}
}

=item _expand_3456_escapes()

Fills in the data for the B<=3> .. B<=6> escapes.

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

=item _expand_escapes()

Fills in the data for all escapes.

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

=item _multi_to_single()

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

=item _followmode()

Fetches the mode of the file, or of the target if it is a symlink.

=cut

sub _followmode {
	my ($self, $file) = @_;
	return $file->{type} ne 'l'
		   ? $file->{mode}
		   : $file->mode2str((stat $file->{name})[2]);
}

##########################################################################
# constructor, getters and setters

=item clobber_mode()

Getter/setter for the clobber mode, which determines if files will be
overwritten without confirmation.

=cut

sub clobber_mode {
	my ($self, $value) = @_;
	$_clobber_mode = $value if defined $value;
	return $_clobber_mode;
}

=item whitecommand()

Getter for the command for listing whiteouts.

=cut

sub whitecommand {
	return $_white_cmd;
}

##########################################################################
# public subs

=item escape_middle()

Sorting routine: sorts digits E<lt> escape character E<lt> letters.

=cut

sub escape_middle {
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
	$_screen->at(0,0)->clreol()->display_error('Command not implemented')
		->set_deferred_refresh(R_MENU);
}

=item handle()

Finds out how an event should be handled, and acts on it.

=cut

sub handle {
	my ($self, $event) = @_;
	my $valid = 1; # assume the event was valid
	for ($event) {
		# order is determined by (supposed) frequency of use
		/^(?:ku|kd|pgup|pgdn|[-+jk\cF\cB\cD\cU]|home|end)$/io
							and $self->handlemove($_),			last;
		/^(?:kr|kl|[h\e\cH])$/io
							and $self->handleentry($_),			last;
		/^[\cE\cY]$/o		and $self->handlescroll($_),		last;
		/^l$/o				and $self->handlekeyell($_),		last;
		/^ $/o				and $self->handleadvance($_),		last;
		/^k5$/o				and $self->handlerefresh(),			last;
#		/^[cr]$/io			and $self->handlecopyrename($_),	last;
#		/^[yo]$/io			and $self->handlecommand($_),		last;
		/^e$/io				and $self->handleedit(),			last;
#		/^(?:d|del)$/io		and $self->handledelete(),			last;
#		/^[ix]$/io			and $self->handleinclude($_),		last;
#		/^\r$/io			and $self->handleenter(),			last;
		/^s$/io				and $self->handleshow(),			last;
#		/^kmous$/o			and $self->handlemousedown(),		last;
		/^k7$/o				and $self->handleswap(),			last;
		/^k10$/o			and $self->handlemultiple(),		last;
#		/^m$/io				and $self->handlemore(),			last;
#		/^p$/io				and $self->handleprint(),			last;
		/^L$/o				and $self->handlelink(),			last;
		/^n$/io				and $self->handlename(),			last;
		/^k8$/o				and $self->handleselect(),			last;
		/^k11$/o			and $self->handlerestat(),			last;
		/^[\/f]$/io			and $self->handlefind(),			last;
		/^[<>]$/io			and $self->handlepan($_,
								$_screen->frame->MENU_SINGLE),	last;
		/^(?:k3|\cL|\cR)$/o	and $self->handlefit(),				last;
		/^t$/io				and $self->handletime(),			last;
		/^a$/io				and $self->handlechmod(),			last;
		/^q$/io				and $valid = $self->handlequit($_),	last;
		/^k6$/o				and $self->handlesort(),			last;
		/^(?:k1|\?)$/o		and $self->handlehelp(),			last;
		/^k2$/o				and $self->handleprev(),			last;
		/^\.$/o				and $self->handledot(),				last;
		/^k9$/o				and $self->handlelayouts(),			last;
		/^k4$/o				and $self->handlecolor(),			last;
		/^\@$/o				and $self->handleperlcommand(),		last;
		/^u$/io				and $self->handlechown(),			last;
#		/^v$/io				and $self->handlercs(),				last;
#		/^z$/io				and $self->handlesize(),			last;
#		/^g$/io				and $self->handletarget(),			last;
		/^k12$/o			and $self->handlemousemode(),		last;
		/^=$/o				and $self->handleident(),			last;
		/^\*$/o				and $self->handleradix(),			last;
		/^!$/o				and $self->handleclobber(),			last;
		/^"$/o				and $self->handlepathmode(),		last;
		/^w$/io				and $self->handleunwo(),			last;
		/^%$/o				and $self->handlewhiteout(),		last;
		$valid = 0; # invalid key
		$_screen->flash();
	}
	return $valid;
}

=item handlepan()

Handles the pan keys B<E<lt>> and B<E<gt>>.

=cut

sub handlepan {
	my ($self, $key, $mode) = @_;
	$_screen->frame->pan($key, $mode);
}

=item handlescroll()

Handles B<CTRL-E> and B<CTRL-Y>, which scroll the current window on the
directory.

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

=item handlemove()

Handles the keys which move around in the current directory.

=cut

sub handlemove {
	my ($self, $key) = @_;
	local $_ = $key;
	my $screenheight  = $_screen->screenheight;
	my $browser       = $_pfm->browser;
	my $baseindex     = $browser->baseindex;
	my $currentline   = $browser->currentline;
	my $showncontents = $_pfm->state->directory->showncontents;
	my $displacement  =
			- (/^(?:ku|k)$/o  )
			+ (/^(?:kd|j| )$/o)
			- (/^-$/o)			* 10
			+ (/^\+$/o)			* 10
			- (/\cB|pgup/o)		* $screenheight
			+ (/\cF|pgdn/o)		* $screenheight
			- (/\cU/o)			* int($screenheight/2)
			+ (/\cD/o)			* int($screenheight/2)
			- (/^home$/o)		* ( $currentline +$baseindex)
			+ (/^end$/o )		* (-$currentline -$baseindex +$#$showncontents);
	$browser->currentline($currentline + $displacement);
}

=item handleprev()

Handles the B<previous> command (B<F2>).

=cut

sub handleprev {
	my $self = shift;
	my $browser = $_pfm->browser;
	my $prevdir = $_pfm->state($_pfm->S_PREV)->directory->path;
	my $chdirautocmd;
	if (chdir $prevdir) {
		# store current cursor position
		$_pfm->state->{_position}  = $browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# perform the swap
		$_pfm->swap_states($_pfm->S_MAIN, $_pfm->S_PREV);
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
	my ($nextdir, $chdirautocmd);
	my $prevstate = $_pfm->state;
	if ($_pfm->state($_pfm->S_SWAP)) {
		if ($swap_persistent) {
			# --------------------------------------------------
			# there is a persistent swap state
			# --------------------------------------------------
			# store current cursor position
			$_pfm->state->{_position}  = $browser->currentfile->{name};
			$_pfm->state->{_baseindex} = $browser->baseindex;
			# perform the swap
			$_pfm->swap_states($_pfm->S_MAIN, $_pfm->S_SWAP);
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
			$_pfm->state(
				$_pfm->S_MAIN,
				$_pfm->state($_pfm->S_SWAP));
			# destroy the swap state
			$_pfm->state($_pfm->S_SWAP, 0);
			# continue below
		}
		# --------------------------------------------------
		# common code for returning to a state
		# --------------------------------------------------
		# toggle swap mode flag
		$browser->swap_mode(!$browser->swap_mode);
		# destination
		$nextdir = $_pfm->state->directory->path;
		# go there using bare chdir() - the state is already up to date
		if (chdir $nextdir) {
			# store the previous main state into S_PREV
			$_pfm->state($_pfm->S_PREV, $prevstate);
			# restore the cursor position
			$browser->baseindex(  $_pfm->state->{_baseindex});
			$browser->position_at($_pfm->state->{_position});
			# autocommand
			$chdirautocmd = $_pfm->config->{chdirautocmd};
			system("$chdirautocmd") if length($chdirautocmd);
			$_screen->set_deferred_refresh(R_SCREEN);
		} else {
			# the state needs refreshing as we counted on being
			# able to chdir()
			$_screen->at($_screen->PATHLINE, 0)->clreol()
				->set_deferred_refresh(R_CHDIR)
				->display_error("$nextdir: $!");
		}
	} else {
		# --------------------------------------------------
		# there is no swap state yet
		# --------------------------------------------------
		# ask and swap forward
		$_screen->at(0,0)->clreol()->cooked_echo();
		$nextdir = $_pfm->history->input(H_PATH, $prompt);
		$_screen->raw_noecho()
			->set_deferred_refresh(R_FRAME);
		return if $nextdir eq '';
		# store current cursor position
		$_pfm->state->{_position}  = $browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $browser->baseindex;
		# store the main state
		$_pfm->state(
			$_pfm->S_SWAP,
			$_pfm->state->clone());
		# toggle swap mode flag
		$browser->swap_mode(!$browser->swap_mode);
		# fix destination
		$self->_expand_escapes(QUOTE_OFF, $nextdir, $browser->currentfile);
		# go there using the directory's chdir() (TODO $swapping flag behavior?)
		if ($_pfm->state->directory->chdir($nextdir, 0)) {
			# set the cursor position
			$browser->baseindex(0);
			$_pfm->state->{multiple_mode} = 0;
			$_pfm->state->{sort_mode} = $_pfm->config->{defaultsortmode} || 'n';
			$_screen->set_deferred_refresh(R_CHDIR);
		}
	}
}

=item handlerefresh()

Handles the command to refresh the current directory.

=cut

sub handlerefresh {
#	my $self = shift;
	if ($_screen->ok_to_remove_marks()) {
		$_screen->set_deferred_refresh(R_DIRCONTENTS | R_DIRSORT | R_SCREEN);
	}
}

=item handlewhiteout()

Toggles the filtering of whiteout files.

=cut

sub handlewhiteout {
	my $self = shift;
	my $browser = $_pfm->browser;
	toggle($_pfm->state->{white_mode});
	$browser->position_at($browser->currentfile->{name});
	$_screen->set_deferred_refresh(R_SCREEN);
}

=item handlemultiple()

Toggles multiple mode.

=cut

sub handlemultiple {
	toggle($_pfm->state->{multiple_mode});
	$_screen->set_deferred_refresh(R_MENU);

}

=item handledot()

Toggles the filtering of dotfiles.

=cut

sub handledot {
	my $self = shift;
	my $browser = $_pfm->browser;
	toggle($_pfm->state->{dot_mode});
	$browser->position_at($browser->currentfile->{name});
	$_screen->set_deferred_refresh(R_SCREEN);
}

=item handlecolor()

Cycles through color modes.

=cut

sub handlecolor {
#	my ($self) = @_;
	$_screen->select_next_color();
}

=item handlemousemode()

Handles turning mouse mode on or off.

=cut

sub handlemousemode {
#	my ($self) = @_;
	my $browser = $_pfm->browser;
	$browser->mouse_mode(!$browser->mouse_mode);
}

=item handlelayouts()

Handles moving on to the next configured layout.

=cut

sub handlelayouts {
#	my ($self) = @_;
	$_screen->listing->select_next_layout();
}

=item handlefit()

Recalculates the screen size and adjusts the layouts.

=cut

sub handlefit {
#	my ($self) = @_;
	$_screen->fit();
}

=item handleident()

Calls the diskinfo class to cycle through showing
the username, hostname or both.

=cut

sub handleident {
#	my ($self) = @_;
	$_screen->diskinfo->select_next_ident();
}

=item handleclobber()

Toggles between clobbering files automatically, or prompting
before overwrite.

=cut

sub handleclobber {
#	my ($self) = @_;
	toggle($_clobber_mode);
	$_screen->set_deferred_refresh(R_FOOTER);
}

=item handlepathmode()

Toggles between logical and physical path mode.

=cut

sub handlepathmode {
#	my ($self) = @_;
	my $directory = $_pfm->state->directory;
	$directory->path_mode($directory->path_mode eq 'phys' ? 'log' : 'phys');
}

=item handleradix()

Toggles between showing nonprintable characters as octal or hexadecimal
codes in the B<N>ame command.

=cut

sub handleradix {
#	my ($self) = @_;
	my $state = $_pfm->state;
	$state->{radix_mode} = ($state->{radix_mode} eq 'hex' ? 'oct' : 'hex');
	$_screen->set_deferred_refresh(R_FOOTER);
}

=item handlequit()

Handles the B<q>uit and quick B<Q>uit commands.

=cut

sub handlequit {
	my ($self, $key) = @_;
	my $confirmquit = $_pfm->config->{confirmquit};
	return 'quit' if isno($confirmquit);
	return 'quit' if $key eq 'Q'; # quick quit
	return 'quit' if
		($confirmquit =~ /marked/i and !$_screen->diskinfo->mark_info);
	$_screen->clear_footer()
		->at(0,0)->clreol()
		->putmessage('Are you sure you want to quit [Y/N]? ');
	my $sure = $_screen->getch();
	return 'quit' if ($sure =~ /y/i);
	$_screen->set_deferred_refresh(R_MENU);
	return 0;
}

=item handleperlcommand()

Handles the B<@> command (execute Perl command).

=cut

sub handleperlcommand {
	my ($self) = @_;
	my $perlcmd;
	# for ease of use when debugging
	my $screen         = $_screen;
	my $listing        = $screen->listing;
	my $config         = $_pfm->config;
	my $browser        = $_pfm->browser;
	my $currentfile    = $browser->currentfile;
	my $state          = $_pfm->state;
	my $directory      = $state->directory;
	my $jobhandler     = $_pfm->jobhandler;
	my $commandhandler = $_pfm->commandhandler;
	my $history        = $_pfm->history;
	# now do!
	$_screen->listing->markcurrentline('@'); # disregard multiple_mode
	$_screen->clear_footer()
		->at(0,0)->clreol()->putmessage('Enter Perl command:')
		->at($_screen->PATHLINE,0)->clreol()->cooked_echo();
	$perlcmd = $_pfm->history->input(H_PERLCMD);
	$_screen->raw_noecho();
	eval $perlcmd;
	$_screen->display_error($@) if $@;
	$_screen->set_deferred_refresh(R_SCREEN);
}

=item handlehelp()

Shows a help page with an overview of commands.

=cut

sub handlehelp {
	my $self = shift;
	$_screen->clrscr()->cooked_echo();
	print map { substr($_, 8)."\n" } split("\n", <<'    _eoHelp_');
        --------------------------------------------------------------------------------
        a     Attrib         mb  make Bookmark     k, up arrow      move one line up    
        c     Copy           mc  Config pfm        j, down arrow    move one line down  
        d DEL Delete         me  Edit any file     -, +             move ten lines      
        e     Edit           mf  make FIFO         CTRL-E, CTRL-Y   scroll dir one line 
        f /   Find           mh  spawn sHell       CTRL-U, CTRL-D   move half a page    
        g     tarGet         mk  Kill children     CTRL-B, CTRL-F   move a full page    
        i     Include        mm  Make new dir      PgUp, PgDn       move a full page    
        L     symLink        mp  Physical path     HOME, END        move to top, bottom 
        n     Name           ms  Show directory    SPACE            mark file & advance 
        o     cOmmand        mt  alTernate scrn    l, right arrow   enter dir           
        p     Print          mv  Versn status all  h, left arrow    leave dir           
        q Q   (Quick) quit   mw  Write history     ENTER            enter dir; launch   
        r     Rename        ---------------------  ESC, BS          leave dir           
        s     Show           !   toggle clobber   --------------------------------------
        t     Time           *   toggle radix      F1  help           F7  swap mode     
        u     Uid            "   toggle pathmode   F2  prev dir       F8  mark file     
        v     Versn status   =   cycle idents      F3  redraw screen  F9  cycle layouts 
        w     unWhiteout     .   filter dotfiles   F4  cycle colors   F10 multiple mode 
        x     eXclude        %   filter whiteouts  F5  reread dir     F11 restat file   
        y     Your command   @   perl command      F6  sort dir       F12 toggle mouse  
        z     siZe           ?   help              <   commands left  >   commands right
        --------------------------------------------------------------------------------
    _eoHelp_
	$_screen->puts("F1 or ? for more elaborate help, any other key for next screen ")
		->raw_noecho();
	if ($_screen->getch() =~ /(k1|\?)/) {
		system qw(man pfm); # how unsubtle :-)
	}
	$self->_credits();
	$_screen->set_deferred_refresh(R_CLRSCR);
}

=item handleentry()

Handles entering or leaving a directory.

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

=item handleselect()

Handles marking (including or excluding) a file.

=cut

sub handleselect {
	my ($self) = @_;
	my $currentfile  = $_pfm->browser->currentfile;
	my $was_selected = $currentfile->{selected} eq App::PFM::Directory->MARK;
	if ($was_selected) {
		$_pfm->state->directory->exclude($currentfile, ' ');
	} else {
		$_pfm->state->directory->include($currentfile);
	}
	# redraw the line now, because we could be moving on
	# to the next file now (space command)
	$_screen->listing->highlight_off();
}

=item handleadvance()

Handles the space key: mark a file and advance to the next one.

=cut

sub handleadvance {
	my ($self, $key) = @_;
	$self->handleselect();
	$self->handlemove($key); # pass space key on
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

Re-executes a stat() on the current (or selected) files.

=cut

sub handlerestat {
#	my ($self) = @_;
	$_pfm->state->directory->apply(sub {});
}

=item handlelink()

Handles the uppercase C<L> key: create hard or symbolic link.

=cut

sub handlelink {
	my ($self) = @_;
	my ($newname, $do_this, $targetstring, $testname, $headerlength,
		$absrel, $histpush);
	my @lncmd = $_clobber_mode ? qw(ln -f) : qw(ln);
	
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_DIRLIST);
	} else {
		$_screen->set_deferred_refresh(R_MENU);
		$_screen->listing->markcurrentline('L');
		$histpush = $_pfm->browser->currentfile->{name};
	}
	
	$headerlength = $_screen->frame->show_menu($_screen->frame->MENU_LNKTYPE);
	$absrel = lc $_screen->at(0, $headerlength+1)->getch();
	return unless $absrel =~ /^[arh]$/;
	push @lncmd, '-s' if $absrel !~ /h/;
	
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	my $prompt = 'Name of new '.
		( $absrel eq 'r' ? 'relative symbolic'
		: $absrel eq 'a' ? 'absolute symbolic' : 'hard') . ' link: ';
	
	chomp($newname = $_pfm->history->input(H_PATH, $prompt, '', $histpush));
	$_screen->raw_noecho();
	return if ($newname eq '');
	$newname = canonicalize_path($newname);
	# expand \[3456] at this point as a test, but not \[1278]
	$self->_expand_3456_escapes(
		QUOTE_OFF, ($testname = $newname), $_pfm->browser->currentfile);
	return if $self->_multi_to_single($testname);
	
	$do_this = sub {
		my $file = shift;
		my $newnameexpanded = $newname;
		my $currentdir      = $_pfm->state->directory->path;
		my ($simpletarget, $simplename);
		# $self is the CommandHandler (because closure)
		$self->_expand_escapes($self->QUOTE_OFF, $newnameexpanded, $file);
		if (-d $newnameexpanded) {
			# make sure $newname is a file (not a directory)
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
		} else { # $absrel eq 'a'
			# hand over an absolute path
			$targetstring = $currentdir.'/'.$file->{name};
		}
		if (system @lncmd, $targetstring, $newnameexpanded) {
			$_screen->neat_error('Linking failed');
		} elsif ($newnameexpanded !~ m!/!) {
			# is newname present in @dircontents? push otherwise
			$_pfm->state->directory
				->addifabsent($newnameexpanded, '', ' ', REFRESH_ASK);
		}
	};
	$_pfm->state->directory->apply($do_this);
}

=item handlesort()

Handles sorting the current directory.

=cut

sub handlesort {
	my ($self) = @_;
	my $printline = $_screen->BASELINE;
	my $infocol   = $_screen->diskinfo->infocol;
	my $frame     = $_screen->frame;
	my %sortmodes = @SORTMODES;
	my ($i, $key, $menulength);
	$menulength = $frame->show_menu($frame->MENU_SORT);
	$frame->show_headings($_pfm->browser->swap_mode, $frame->HEADING_SORT);
	$_screen->frame->clear_footer();
	$_screen->diskinfo->clearcolumn();
	# we can't use foreach (keys %SORTMODES) because we would lose ordering
	foreach (grep { ($i += 1) %= 2 } @SORTMODES) { # keep keys, skip values
		$_screen->at($printline++, $infocol)
			->puts(sprintf('%1s %s', $_, $sortmodes{$_}));
	}
	$key = $_screen->at(0, $menulength)->getch();
	$_screen->diskinfo->clearcolumn();
	if ($sortmodes{$key}) {
		$_pfm->state->{sort_mode} = $key;
		$_pfm->browser->position_at($_pfm->browser->currentfile->{name});
	}
	$_screen->set_deferred_refresh(R_DIRSORT | R_SCREEN);
}

=item handlename()

Shows all chacacters of the filename in a readable manner.

=cut

sub handlename {
	my ($self) = @_;
	my $numformat   = $NUMFORMATS{$_pfm->state->{radix_mode}};
	my $browser     = $_pfm->browser;
	my $workfile    = $browser->currentfile->clone();
	my $screenline  = $browser->currentline + $_screen->BASELINE;
	my $filenamecol = $_screen->listing->filenamecol;
	my $trspace     = $_pfm->config->{trspace};
	my ($line, $linecolor);
	$_screen->listing->markcurrentline('N'); # disregard multiple_mode
#	$_screen->clear_footer();
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
		$_screen->frame->show_footer();
		$_screen->echo()->at($screenline, $filenamecol)
			->puts(' ' x length $line);
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

=item handlefind_incremental()

Prompts for a filename to find, and positions the cursor while the name
is typed (incremental find). Only applicable if the current sort_mode
is by name (ascending or descending).

=cut

sub handlefind {
	my ($self) = @_;
	if (lc($_pfm->state->{sort_mode}) eq 'n') {
		goto &handlefind_incremental;
	}
	my ($findme, $file);
	my $prompt = 'File to find: ';
	$_screen->at(0,0)->clreol()->cooked_echo();
	($findme = $_pfm->history->input(H_PATH, $prompt)) =~ s/\/$//;
	if ($findme =~ /\//) { $findme = basename($findme) };
	$_screen->raw_noecho()->set_deferred_refresh(R_MENU);
	return if $findme eq '';
	FINDENTRY:
	foreach $file (sort by_name @{$_pfm->state->directory->showncontents}) {
		last FINDENTRY if $findme le $file->{name};
	}
	$_pfm->browser->position_at($findme);
	$_screen->set_deferred_refresh(R_DIRLIST);
}

sub handlefind_incremental {
	my ($self) = @_;
	my ($findme, $key, $screenline);
	my $prompt = 'File to find: ';
	my $cursorjumptime = .5;
	my $cursorcol = $_screen->listing->cursorcol;
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

Starts the editor for editing the current fileZ<>(s).

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

Handles changing the owner of a file.

=cut

sub handlechown {
	my ($self) = @_;
	my ($newuid, $do_this);
	my $prompt = 'New [user][:group] ';
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_DIRLIST);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('U');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newuid = $_pfm->history->input(H_MODE, $prompt));
	$_screen->raw_noecho();
	return if ($newuid eq '');
	$do_this = sub {
		my $file = shift;
		if (system ('chown', $newuid, $file->{name})) {
			$_screen->neat_error('Change owner failed');
		}
	};
	$_pfm->state->directory->apply($do_this);
}

=item handlechmod()

Handles changing the mode (permission bits) of a file.

=cut

sub handlechmod {
	my ($self) = @_;
	my ($newmode, $do_this);
	my $prompt = 'New mode [ugoa][-=+][rwxslt] or octal: ';
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_DIRLIST); # R_DIRFILTER?
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('A');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	chomp($newmode = $_pfm->history->input(H_MODE, $prompt));
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

Handles changing the timestamp of a file.

=cut

sub handletime {
	my ($self) = @_;
	my ($newtime, $do_this, @cmdopts);
	my $prompt = "Timestamp [[CC]YY]-MM-DD hh:mm[.ss]: ";
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO | R_DIRLIST);
	} else {
		$_screen->set_deferred_refresh(R_MENU | R_PATHINFO);
		$_screen->listing->markcurrentline('T');
	}
	$_screen->clear_footer()->at(0,0)->clreol()->cooked_echo();
	$newtime = $_pfm->history->input(H_TIME, $prompt,
		strftime ("%Y-%m-%d %H:%M.%S", localtime time));
	$_screen->raw_noecho();
	$newtime =~ tr/0-9.//cd;
	return if ($newtime eq '');
	@cmdopts = ($newtime eq '.') ? () : ('-t', $newtime);
	$do_this = sub {
		my $file = shift;
		if (system ('touch', @cmdopts, $file->{name})) {
			$_screen->neat_error('Set timestamp failed');
		}
	};
	$_pfm->state->directory->apply($do_this);
}

=item handleshow()

Handles displaying the contents of a file.

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
		$_screen->puts($file->{name})
			->alternate_off();
		system $_pfm->config->{pager}." \Q$file->{name}\E"
			and display_error("Pager failed\n");
		$_screen->alternate_on() if $_pfm->config->{altscreen_mode};
	};
	$_pfm->state->directory->apply($do_this);
	$_screen->raw_noecho()->set_deferred_refresh(R_CLRSCR);
}

=item handleunwo()

Handles removing a whiteout file.

=cut

sub handleunwo {
	my ($self) = @_;
	my ($do_this);
	my $nowhiteouterror = 'Current file is not a whiteout';
	if ($_pfm->state->{multiple_mode}) {
		$_screen->set_deferred_refresh(R_MENU | R_DIRLIST);
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
			if (system(@_unwo_cmd, $file->{name})) {
				$_screen->neat_error('Whiteout removal failed');
			}
		} else {
			$_screen->neat_error($nowhiteouterror);
		}
	};
	$_pfm->state->directory->apply($do_this);
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
