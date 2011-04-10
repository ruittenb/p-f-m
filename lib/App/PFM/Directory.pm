#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Directory 0.12
#
# Name:			App::PFM::Directory
# Version:		0.12
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-10
#

##########################################################################

=pod

=head1 NAME

App::PFM::Directory

=head1 DESCRIPTION

PFM Directory class, containing the directory contents and the
actions that can be performed on them.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Directory;

use base 'App::PFM::Abstract';

use App::PFM::Job::Subversion;
use App::PFM::Job::Cvs;
use App::PFM::Job::Bazaar;
use App::PFM::Job::Git;
use App::PFM::File;
use App::PFM::Util;
use POSIX qw(getcwd);

use strict;

use constant {
	SLOWENTRIES	=> 300,
	MARK		=> '*',
	OLDMARK		=> '.',
	NEWMARK		=> '~',
};

my $DFCMD = ($^O eq 'hpux') ? 'bdf' : ($^O eq 'sco') ? 'dfspace' : 'df -k';

my ($_pfm,
	$_path_mode);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	 = @_;
	$_pfm					 = $pfm;
	$self->{_path}			 = $path;
	$self->{_dircontents}	 = [];
	$self->{_showncontents}	 = [];
	$self->{_selected_nr_of} = {};
	$self->{_total_nr_of}	 = {};
	$self->{_disk}			 = {};
}

=item _clone()

Performs one phase of the cloning process by cloning an existing
App::PFM::Directory instance.

=cut

sub _clone {
	my ($self, $original, @args) = @_;
	$self->{_dircontents}	 = [ @{$original->{_dircontents}	} ];
	# TODO we may want to keep the same references to _dircontents
	# - or we may need to clone() the files.
	$self->{_showncontents}	 = [ @{$original->{_showncontents}	} ];
	$self->{_selected_nr_of} = { %{$original->{_selected_nr_of}	} };
	$self->{_total_nr_of}	 = { %{$original->{_total_nr_of}	} };
	$self->{_disk}			 = { %{$original->{_disk}			} };
}

=item _by_sort_mode()

Sorts two directory entries according to the selected sort mode.

=cut

sub _by_sort_mode {
	# note: called directly (not OO-like)
	my ($exta, $extb);
	if ($_pfm->config->{dotdot_mode}) {
		# Oleg Bartunov requested to have . and .. unsorted (always at the top)
		if    ($a->{name} eq '.' ) { return -1 }
		elsif ($b->{name} eq '.' ) { return  1 }
		elsif ($a->{name} eq '..') { return -1 }
		elsif ($b->{name} eq '..') { return  1 }
	}
	SWITCH:
	for ($_pfm->state->{sort_mode}) {
		/n/ and return		$a->{name}  cmp		$b->{name},	last SWITCH;
		/N/ and return		$b->{name}  cmp		$a->{name},	last SWITCH;
		/m/ and return	 lc($a->{name}) cmp  lc($b->{name}),last SWITCH;
		/M/ and return	 lc($b->{name}) cmp  lc($a->{name}),last SWITCH;
		/d/ and return		$a->{mtime} <=>		$b->{mtime},last SWITCH;
		/D/ and return		$b->{mtime} <=>		$a->{mtime},last SWITCH;
		/a/ and return		$a->{atime} <=>		$b->{atime},last SWITCH;
		/A/ and return		$b->{atime} <=>		$a->{atime},last SWITCH;
		/s/ and return		$a->{size}  <=>		$b->{size},	last SWITCH;
		/S/ and return		$b->{size}  <=>		$a->{size},	last SWITCH;
		/z/ and return		$a->{grand} <=>		$b->{grand},last SWITCH;
		/Z/ and return		$b->{grand} <=>		$a->{grand},last SWITCH;
		/i/ and return		$a->{inode} <=>		$b->{inode},last SWITCH;
		/I/ and return		$b->{inode} <=>		$a->{inode},last SWITCH;
		/v/ and return		$a->{rcs}   cmp		$b->{rcs},  last SWITCH;
		/V/ and return		$b->{rcs}   cmp		$a->{rcs},  last SWITCH;
		/t/ and return $a->{type}.$a->{name}
									  cmp $b->{type}.$b->{name}, last SWITCH;
		/T/ and return $b->{type}.$b->{name}
									  cmp $a->{type}.$a->{name}, last SWITCH;
		/[ef]/i and do {
			 if ($a->{name} =~ /^(.*)(\.[^\.]+)$/) { $exta = $2."\0377".$1 }
											 else { $exta = "\0377".$a->{name} }
			 if ($b->{name} =~ /^(.*)(\.[^\.]+)$/) { $extb = $2."\0377".$1 }
											 else { $extb = "\0377".$b->{name} }
			 /e/ and return    $exta  cmp    $extb, 		last SWITCH;
			 /E/ and return    $extb  cmp    $exta, 		last SWITCH;
			 /f/ and return lc($exta) cmp lc($extb),		last SWITCH;
			 /F/ and return lc($extb) cmp lc($exta),		last SWITCH;
		};
	}
}

=item _init_filesystem_info()

Determines the current filesystem usage and stores it in an internal hash.

=cut

sub _init_filesystem_info {
	my $self = shift;
	my @dflist;
	chop (@dflist = (`$DFCMD \Q$self->{_path}\E`, ''));
	shift @dflist; # skip header
	$dflist[0] .= $dflist[1]; # in case filesystem info wraps onto next line
	@{$self->{_disk}}{qw/device total used avail/} = split (/\s+/, $dflist[0]);
	if ($self->{_disk}{avail} =~ /%/) {
		$self->{_disk}{avail} = $self->{_disk}{total} - $self->{_disk}{used};
	}
	$dflist[0] =~ /(\S*)$/;
	$self->{_disk}{mountpoint} = $1;
	return $self->{_disk};
}

##########################################################################
# constructor, getters and setters

=item path()

Getter/setter for the current directory path.
Setting the current directory in this way is identical to calling
App::PFM::Directory::chdir(), and will return the success status.

=cut

sub path {
	my $self = shift;
	if (@_) {
		return $self->chdir(@_);
	}
	return $self->{_path};
}

=item dircontents()

Getter/setter for the $_dircontents variable, which points to the
complete array of files in the directory.

=cut

sub dircontents {
	my ($self, $value) = @_;
	$self->{_dircontents} = $value if defined $value;
	return $self->{_dircontents};
}

=item showncontents()

Getter/setter for the $_showncontents variable, which points to the
array of the files shown on-screen.

=cut

sub showncontents {
	my ($self, $value) = @_;
	$self->{_showncontents} = $value if defined $value;
	return $self->{_showncontents};
}

=item total_nr_of()

Getter for the hash which keeps track of how many directory entities
of each type there are.

=cut

sub total_nr_of {
	return $_[0]->{_total_nr_of};
}

=item selected_nr_of()

Getter for the hash which keeps track of how many directory entities
of each type have been selected.

=cut

sub selected_nr_of {
	return $_[0]->{_selected_nr_of};
}

=item disk()

Getter for the hash which keeps track of filesystem information:
usage, mountpoint and device.

=cut

sub disk {
	return $_[0]->{_disk};
}

=item mountpoint()

Getter/setter for the mountpoint on which the current directory is situated.

=cut

sub mountpoint {
	my ($self, $value) = @_;
	$self->{_disk}{mountpoint} = $value if defined $value;
	return $self->{_disk}{mountpoint};
}

=item device()

Getter/setter for the device on which the current directory is situated.

=cut

sub device {
	my ($self, $value) = @_;
	$self->{_disk}{device} = $value if defined $value;
	return $self->{_disk}{device};
}

=item path_mode()

Getter/setter for the path mode setting (physical or logical).

=cut

sub path_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		my $screen = $_pfm->screen;
		$self->{_path_mode} = $value;
		$self->{_path} = getcwd() if $self->{_path_mode} eq 'phys';
		$screen->set_deferred_refresh($screen->R_FOOTER | $screen->R_PATHINFO);
	}
	return $self->{_path_mode};
}

##########################################################################
# public subs

=item prepare()

Prepares the contents of this directory object. Called in case this state
is not to be displayed on-screen right away.

=cut

sub prepare {
	my ($self, $path) = @_;
	$self->path_mode($_pfm->config->{path_mode});
	$self->{_path} = $path;
	$self->_init_filesystem_info();
	$self->readcontents();
	$self->sortcontents();
	$self->filtercontents();
}

=item chdir()

Tries to change the current working directory, if necessary using B<CDPATH>.
If successful, it stores the previous state in @App::PFM::Application::_states
and executes the 'chdirautocmd' from the F<.pfmrc> file.
The 'swapping' argument can be passed as true to prevent undesired pathname
parsing during pfm's B<F7> command.

=cut

sub chdir {
	my ($self, $nextdir, $swapping, $direction) = @_;
	my ($success, $chdirautocmd, $nextpos);
	my $screen = $_pfm->screen;
	my $prevdir = $self->{_path};
	if ($nextdir eq '') {
		$nextdir = $ENV{HOME};
	} elsif (-d $nextdir and $nextdir !~ m!^/!) {
		$nextdir = "$prevdir/$nextdir";
	} elsif ($nextdir !~ m!/!) {
		foreach (split /:/, $ENV{CDPATH}) {
			if (-d "$_/$nextdir") {
				$nextdir = "$_/$nextdir";
				$screen->at(0,0)->clreol()
					->display_error("Using $nextdir")
					->at(0,0);
				last;
			}
		}
	}
	$nextdir = canonicalize_path($nextdir);
	if ($success = chdir $nextdir and $nextdir ne $prevdir) {
		# store the cursor position in the state
		$_pfm->state->{_position}  = $_pfm->browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $_pfm->browser->baseindex;
		unless ($swapping) {
			$_pfm->state($_pfm->S_PREV, $_pfm->state->clone($_pfm));
		}
		if ($_path_mode eq 'phys') {
			$self->{_path} = getcwd();
		} else {
			$self->{_path} = $nextdir;
		}
		# restore the cursor position
		if ($swapping) {
			$_pfm->browser->position_at($_pfm->state->{_position});
			$_pfm->browser->baseindex(  $_pfm->state->{_baseindex});
			$screen->set_deferred_refresh($screen->R_SCREEN);
		} else {
			$nextpos = $direction eq 'up'
				? basename($prevdir)
				: $direction eq 'down' ? '..' : '.';
			$_pfm->browser->position_at($nextpos);
			$_pfm->browser->baseindex(0);
			$screen->set_deferred_refresh($screen->R_CHDIR);
			$self->_init_filesystem_info();
		}
		$chdirautocmd = $_pfm->config->{chdirautocmd};
		system("$chdirautocmd") if length($chdirautocmd);
	}
	return $success;
}

=item init_dircount()

Initializes the total number of entries of each type in the current
directory by zeroing them out.

=cut

sub init_dircount {
	my $self = shift;
	%{$self->{_selected_nr_of}} =
		%{$self->{_total_nr_of}} =
			( d=>0, '-'=>0, l=>0, c=>0, b=>0, D=>0,
			  p=>0, 's'=>0, n=>0, w=>0, bytes => 0 );
}

=item countcontents()

Counts the total number of entries of each type in the current directory.

=cut

sub countcontents {
	my $self = shift;
	$self->init_dircount();
	foreach my $i (0..$#_) {
		$self->{_total_nr_of   }{$_[$i]{type}}++;
		$self->{_selected_nr_of}{$_[$i]{type}}++ if ($_[$i]{selected} eq MARK);
	}
}

=item readcontents()

Reads the entries in the current directory and performs a stat() on them.

=cut

sub readcontents {
	my $self = shift;
	my ($entry, $file);
	my @allentries    = ();
	my @white_entries = ();
	my $whitecommand  = $_pfm->commandhandler->whitecommand;
	my $screen        = $_pfm->screen;
	clearugidcache();
	$self->init_dircount();
	$App::PFM::File::_pfm = $_pfm;
	$self->{_dircontents}   = [];
	$self->{_showncontents} = [];
	# don't use '.' as the directory path to open: we may be just
	# prepare()ing this object without actually entering the directory
	if (opendir CURRENT, $self->{_path}) {
		@allentries = readdir CURRENT;
		closedir CURRENT;
		if ($whitecommand) {
			@white_entries = `$whitecommand \Q$self->{_path}\E`;
		}
	} else {
		$screen->at(0,0)->clreol()->display_error("Cannot read . : $!");
	}
	# next lines also correct for directories with no entries at all
	# (this is sometimes the case on NTFS filesystems: why?)
	if ($#allentries < 0) {
		@allentries = ('.', '..');
	}
	if ($#allentries > SLOWENTRIES) {
		$screen->at(0,0)->clreol()->putmessage('Please Wait');
	}
	foreach $entry (@allentries) {
		# have the mark cleared on first stat with ' '
		$self->add($entry, '', ' ');
		#$file = new App::PFM::File($entry, $self->{_path}, '', ' ');
		#push @{$self->{_dircontents}}, $file;
		#$self->register($file);
	}
	foreach $entry (@white_entries) {
		$self->add($entry, 'w', ' ');
		#$file = new App::PFM::File($entry, $self->{_path}, 'w', ' ');
		#push @{$self->{_dircontents}}, $file;
		#$self->register($file);
	}
	$screen->set_deferred_refresh($screen->R_MENU | $screen->R_HEADINGS);
	$self->checkrcsapplicable() if $_pfm->config->{autorcs};
	return $self->{_dircontents};
}

=item sortcontents()

Sorts the directory's contents according to the selected sort mode.

=cut

sub sortcontents {
	my $self = shift;
	@{$self->{_dircontents}} = sort _by_sort_mode @{$self->{_dircontents}};
}

=item filtercontents()

Filters the directory contents according to the filter modes
(displays or hides dotfiles and whiteouts).

=cut

sub filtercontents {
	my $self = shift;
	@{$self->{_showncontents}} = grep {
		$_pfm->state->{dot_mode}   || $_->{name} =~ /^(\.\.?|[^\.].*)$/ and
		$_pfm->state->{white_mode} || $_->{type} ne 'w'
	} @{$self->{_dircontents}};
}

=item addifabsent()

Checks if the file is not yet in the directory. If not, add()s it.

=cut

sub addifabsent {
	my ($self, $entry, $white, $mark, $flag_refresh) = @_;
	my $findindex = 0;
	my $dircount  = $#{$self->{_dircontents}};
	my $file;
	$findindex++ while ($findindex <= $dircount and
					   $entry ne ${$self->{_dircontents}}[$findindex]{name});
	if ($findindex > $dircount) {
		$self->add($entry, $white, $mark, $flag_refresh);
	} else {
		$file = ${$self->{_dircontents}}[$findindex];
		$self->unregister($file);
		# copy $white from caller, it may be a whiteout.
		# copy $mark  from file (preserve).
		$file->stat_entry($file->{name}, $white, $file->{selected});
		$self->register($file);
		# flag screen refresh
		if ($flag_refresh) {
			my $screen = $_pfm->screen;
			$screen->set_deferred_refresh(
				$screen->R_DIRLIST | $screen->R_DIRFILTER | $screen->R_DIRSORT);
		}
	}
}

=item add()

Adds the entry as file to the directory. Also calls register().

=cut

sub add {
	my ($self, $entry, $white, $mark, $flag_refresh) = @_;
	my $file = new App::PFM::File($entry, $self->{_path}, $white, $mark);
	push @{$self->{_dircontents}}, $file;
	$self->register($file);
	if ($flag_refresh) {
		my $screen = $_pfm->screen;
		$screen->set_deferred_refresh(
			$screen->R_DIRLIST | $screen->R_DIRFILTER | $screen->R_DIRSORT);
	}
}

=item register()

Adds the file to the internal counters.

=cut

sub register {
	my ($self, $entry) = @_;
	$self->{_total_nr_of}{$entry->{type}}++;
	if ($entry->{selected} eq MARK) {
		$self->include($entry);
	}
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item unregister()

Removes the file from the internal counters.

=cut

sub unregister {
	my ($self, $entry) = @_;
	$self->{_total_nr_of}{$entry->{type}}--;
	if ($entry->{selected} eq MARK) {
		# exclude it but leave the mark in place
		$self->exclude($entry, MARK);
	}
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item include()

Marks a file.

=cut

sub include {
	my ($self, $entry) = @_;
	$entry->{selected} = MARK;
	$self->{_selected_nr_of}{$entry->{type}}++;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} += $entry->{size};
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item exclude()

Removes a file's mark.

=cut

sub exclude {
	my ($self, $entry, $oldmark) = @_;
	$oldmark ||= ' ';
	$entry->{selected} = $oldmark;
	$self->{_selected_nr_of}{$entry->{type}}--;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} -= $entry->{size};
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item checkrcsapplicable()

Checks if any rcs jobs are applicable for this directory,
and starts them.

=cut

sub checkrcsapplicable {
	my ($self) = @_;
	my $path = $self->{_path};
	if (App::PFM::Job::Subversion->isapplicable($path)) {
		$_pfm->jobhandler->start('Subversion');
		return;
	}
	if (App::PFM::Job::Cvs->isapplicable($path)) {
		$_pfm->jobhandler->start('Cvs');
		return;
	}
	if (App::PFM::Job::Bazaar->isapplicable($path)) {
		$_pfm->jobhandler->start('Bazaar');
		return;
	}
	if (App::PFM::Job::Git->isapplicable($path)) {
		$_pfm->jobhandler->start('Git');
		return;
	}
}

=item apply()

In single file mode: applies the supplied function to the current file.
In multiple file mode: applies the supplied function to all selected files
in the current directory.

=cut

sub apply {
	my ($self, $do_this, @args) = @_;
	my ($i, $loopfile);
	if ($_pfm->state->{multiple_mode}) {
		my $screen = $_pfm->screen;
		foreach $i (0 .. $#{$self->{_showncontents}}) {
			$loopfile = $self->{_showncontents}[$i];
			if ($loopfile->{selected} eq MARK) {
				$screen->at($screen->PATHLINE, 0)->clreol()
					->puts($loopfile->{name})->at($screen->PATHLINE+1, 0);
				$loopfile->apply($do_this, @args);
			}
		}
		$_pfm->state->{multiple_mode} = 0 if $_pfm->config->{autoexitmultiple};
		# TODO if the bloody thing is deleted,
		# it should be deleted from _dircontents as well (or maybe create
		# a separate loop for deletions?)
		$screen->set_deferred_refresh(
			$screen->R_DIRLIST | $screen->R_PATHINFO | $screen->R_FRAME);
	} else {
		$_pfm->browser->currentfile->apply($do_this, @args);
	}
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
