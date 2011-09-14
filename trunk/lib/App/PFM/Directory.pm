#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Directory 0.81
#
# Name:			App::PFM::Directory
# Version:		0.81
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-25
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

use base qw(App::PFM::Abstract Exporter);

use App::PFM::Job::Subversion;
use App::PFM::Job::Cvs;
use App::PFM::Job::Bazaar;
use App::PFM::Job::Git;
use App::PFM::File;
use App::PFM::Util qw(clearugidcache canonicalize_path basename dirname);
use POSIX qw(getcwd);

use strict;

use constant {
	RCS_DONE	=> 0,
	RCS_RUNNING	=> 1,
	SLOWENTRIES	=> 300,
	M_MARK		=> '*',
	M_OLDMARK	=> '.',
	M_NEWMARK	=> '~',
};

use constant RCS => [
	'Subversion',
	'Cvs',
	'Bazaar',
	'Git',
];

our @EXPORT = qw(M_MARK M_OLDMARK M_NEWMARK);

our ($_pfm);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	 = @_;
	$_pfm					 = $pfm;
	$self->{_path}			 = $path;
	$self->{_path_mode}		 = 'log';
	$self->{_wasquit}		 = undef;
	$self->{_rcsjob}		 = undef;
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
	# note: we are not cloning the files here.
	$self->{_dircontents}	 = [ @{$original->{_dircontents}	} ];
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
	for ($_pfm->state->{sort_mode}) {
		/n/  and return		$a->{name}		cmp		$b->{name};
		/N/  and return		$b->{name}		cmp		$a->{name};
		/m/  and return	 lc($a->{name})		cmp	 lc($b->{name});
		/M/  and return	 lc($b->{name})		cmp	 lc($a->{name});
		/d/  and return		$a->{mtime}		<=>		$b->{mtime};
		/D/  and return		$b->{mtime}		<=>		$a->{mtime};
		/a/  and return		$a->{atime}		<=>		$b->{atime};
		/A/  and return		$b->{atime}		<=>		$a->{atime};
		/s/  and return		$a->{size}		<=>		$b->{size};
		/S/  and return		$b->{size}		<=>		$a->{size};
		/z/  and return		$a->{grand}		<=>		$b->{grand};
		/Z/  and return		$b->{grand}		<=>		$a->{grand};
		/i/  and return		$a->{inode}		<=>		$b->{inode};
		/I/  and return		$b->{inode}		<=>		$a->{inode};
		/u/  and return		$a->{uid}		cmp		$b->{uid};
		/U/  and return		$b->{uid}		cmp		$a->{uid};
		/g/  and return		$a->{gid}		cmp		$b->{gid};
		/G/  and return		$b->{gid}		cmp		$a->{gid};
		/v/  and return		$a->{rcs}		cmp		$b->{rcs};
		/V/  and return		$b->{rcs}		cmp		$a->{rcs};
		/t/  and do {
				if ($a->{type} eq $b->{type}) {
					return $a->{name} cmp $b->{name};
				}
				elsif ($a->{type} eq 'd') { return -1 }
				elsif ($b->{type} eq 'd') { return  1 }
				return $a->{type} cmp $b->{type};
		};
		/T/  and do {
				if ($a->{type} eq $b->{type}) {
					return $b->{name} cmp $a->{name};
				}
				elsif ($b->{type} eq 'd') { return -1 }
				elsif ($a->{type} eq 'd') { return  1 }
				return $b->{type} cmp $a->{type};
		};
		/\*/ and do {
				if ($a->{selected} eq $b->{selected}) {
					return $a->{name} cmp $b->{name};
				}
				elsif ($a->{selected} eq M_MARK   ) { return -1 }
				elsif ($b->{selected} eq M_MARK   ) { return  1 }
				elsif ($a->{selected} eq M_NEWMARK) { return -1 }
				elsif ($b->{selected} eq M_NEWMARK) { return  1 }
				elsif ($a->{selected} eq M_OLDMARK) { return -1 }
				elsif ($b->{selected} eq M_OLDMARK) { return  1 }
				return $a->{selected} cmp $b->{selected};
		};
		/[ef]/i and do {
			 if ($a->{name} =~ /^(.*)(\.[^\.]+)$/) { $exta = $2."\0377".$1 }
											 else { $exta = "\0377".$a->{name} }
			 if ($b->{name} =~ /^(.*)(\.[^\.]+)$/) { $extb = $2."\0377".$1 }
											 else { $extb = "\0377".$b->{name} }
			 /e/ and return    $exta  cmp    $extb;
			 /E/ and return    $extb  cmp    $exta;
			 /f/ and return lc($exta) cmp lc($extb);
			 /F/ and return lc($extb) cmp lc($exta);
		};
	}
}

=item _init_filesystem_info()

Determines the current filesystem usage and stores it in an internal hash.

=cut

sub _init_filesystem_info {
	my ($self) = @_;
	my @dflist;
	chop (@dflist = $_pfm->os->df($self->{_path}));
	shift @dflist; # skip header
	@{$self->{_disk}}{qw/device total used avail/} = split (/\s+/, $dflist[0]);
	$dflist[0] =~ /(\S*)$/;
	$self->{_disk}{mountpoint} = $1;
	return $self->{_disk};
}

=item _catch_quit()

Catches terminal quit signals (SIGQUIT).

=cut

sub _catch_quit {
	my ($self) = @_;
	$self->{_wasquit} = 1;
	$SIG{QUIT} = \&_catch_quit;
}

##########################################################################
# constructor, getters and setters

=item path()

Getter/setter for the current directory path.
Setting the current directory in this way is identical to calling
App::PFM::Directory::chdir(), and will return the success status.

=cut

sub path {
	my ($self, @cdopts) = @_;
	if (@cdopts) {
		return $self->chdir(@cdopts);
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
If successful, it stores the previous state in App::PFM::Application->_states
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
			$_pfm->state('S_PREV', $_pfm->state->clone());
		}
		if ($self->{_path_mode} eq 'phys') {
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
	my ($self) = @_;
	%{$self->{_selected_nr_of}} =
		%{$self->{_total_nr_of}} =
			( d=>0, '-'=>0, l=>0, c=>0, b=>0, D=>0, P=>0,
			  p=>0, 's'=>0, n=>0, w=>0, bytes => 0 );
}

=item countcontents()

Counts the total number of entries of each type in the current directory.

=cut

sub countcontents {
	my ($self, @entries) = @_;
	$self->init_dircount();
	foreach my $i (0..$#entries) {
		$self->{_total_nr_of   }{$entries[$i]{type}}++;
		$self->{_selected_nr_of}{$entries[$i]{type}}++
			if $entries[$i]{selected} eq M_MARK;
	}
}

=item readcontents()

Reads the entries in the current directory and performs a stat() on them.

=cut

sub readcontents {
	my ($self) = @_;
	my ($entry, $file);
	my @allentries    = ();
	my @white_entries = ();
	my $screen        = $_pfm->screen;
	# TODO stop jobs here
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
		@white_entries = $_pfm->os->listwhite($self->{_path});
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
		$self->add(
			entry => $entry,
			white => '',
			mark  => ' ');
	}
	foreach $entry (@white_entries) {
		$self->add(
			entry => $entry,
			white => 'w',
			mark  => ' ');
	}
	$screen->set_deferred_refresh($screen->R_MENU | $screen->R_HEADINGS);
	$self->checkrcsapplicable() if $_pfm->config->{autorcs};
	return $self->{_dircontents};
}

=item sortcontents()

Sorts the directory's contents according to the selected sort mode.

=cut

sub sortcontents {
	my ($self) = @_;
	@{$self->{_dircontents}} = sort _by_sort_mode @{$self->{_dircontents}};
}

=item filtercontents()

Filters the directory contents according to the filter modes
(displays or hides dotfiles and whiteouts).

=cut

sub filtercontents {
	my ($self) = @_;
	@{$self->{_showncontents}} = grep {
		$_pfm->state->{dot_mode}   || $_->{name} =~ /^(\.\.?|[^\.].*)$/ and
		$_pfm->state->{white_mode} || $_->{type} ne 'w'
	} @{$self->{_dircontents}};
}

=item addifabsent()

Checks if the file is not yet in the directory. If not, add()s it.

=cut

sub addifabsent {
	my ($self, %o) = @_; # ($entry, $white, $mark, $refresh);
	my $findindex = 0;
	my $dircount  = $#{$self->{_dircontents}};
	my $file;
	$findindex++ while ($findindex <= $dircount and
					   $o{entry} ne ${$self->{_dircontents}}[$findindex]{name});
	if ($findindex > $dircount) {
		$self->add(%o);
	} else {
		$file = ${$self->{_dircontents}}[$findindex];
		$self->unregister($file);
		# copy $white from caller, it may be a whiteout.
		# copy $mark  from file (preserve).
		$file->stat_entry($file->{name}, $o{white}, $file->{selected});
		$self->register($file);
		# flag screen refresh
		if ($o{refresh}) {
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
	my ($self, %o) = @_; # ($entry, $white, $mark, $refresh);
	my $file = new App::PFM::File(%o, parent => $self->{_path});
	push @{$self->{_dircontents}}, $file;
	$self->register($file);
	if ($o{refresh}) {
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
	if ($entry->{selected} eq M_MARK) {
		$self->register_include($entry);
	}
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item unregister()

Removes the file from the internal counters.

=cut

sub unregister {
	my ($self, $entry) = @_;
	my $prevmark;
	$self->{_total_nr_of}{$entry->{type}}--;
	if ($entry->{selected} eq M_MARK) {
		$prevmark = $self->register_exclude($entry);
	}
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
	return $prevmark;
}

=item include()

Marks a file.

=cut

sub include {
	my ($self, $entry) = @_;
	$self->register_include($entry) if ($entry->{selected} ne M_MARK);
	$entry->{selected} = M_MARK;
}

=item exclude()

Removes a file's mark.

=cut

sub exclude {
	my ($self, $entry, $to_mark) = @_;
	my $prevmark = $entry->{selected};
	$self->register_exclude($entry) if ($entry->{selected} eq M_MARK);
	$entry->{selected} = $to_mark || ' ';
	return $prevmark;
}

=item register_include()

Adds a file to the counters of marked files.

=cut

sub register_include {
	my ($self, $entry) = @_;
	$self->{_selected_nr_of}{$entry->{type}}++;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} += $entry->{size};
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item register_exclude()

Removes a file from the counters of marked files.

=cut

sub register_exclude {
	my ($self, $entry) = @_;
	$self->{_selected_nr_of}{$entry->{type}}--;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} -= $entry->{size};
	$_pfm->screen->set_deferred_refresh($_pfm->screen->R_DISKINFO);
}

=item checkrcsapplicable()

Checks if any rcs jobs are applicable for this directory,
and starts them.

=cut

sub checkrcsapplicable {
	my ($self, $entry) = @_;
	my ($class, $fullclass);
	my $path   = $self->{_path};
	my $screen = $_pfm->screen;
	$entry = defined $entry ? $entry : $path;
	my $on = {
		after_start			=> sub {
			# next line needs to provide a '1' argument because
			# $self->{_rcsjob} has not yet been set
			$screen->set_deferred_refresh($screen->R_HEADINGS);
			$screen->frame->rcsrunning(RCS_RUNNING);
		},
		after_receive_data	=> sub {
			my $job = shift;
			my ($flags, $file) = @{ shift() };
			my ($topdir, $mapindex, $oldval);
			my $count = 0;
			my %nameindexmap =
				map { $_->{name}, $count++ } @{$self->{_showncontents}};
			if (substr($file, 0, length($path)) eq $path) {
				$file = substr($file, length($path)+1); # +1 for trailing /
			}
			# currentdir or subdir?
			if ($file =~ m!/!) {
				# change in subdirectory
				($topdir = $file) =~ s!/.*!!;
				$mapindex = $nameindexmap{$topdir};
				# find highest prio marker
				$oldval = $self->{_showncontents}[$mapindex]{rcs};
				$self->{_showncontents}[$mapindex]{rcs} =
					$job->rcsmax($oldval, $flags);
#				# if there was a change in a subdir, then show M on currentdir
#				$mapindex = $nameindexmap{'.'};
#				# find highest prio marker
#				$oldval = $self->{_showncontents}[$mapindex]{rcs};
#				$self->{_showncontents}[$mapindex]{rcs} =
#					$job->rcsmax($oldval, 'M');
			} else {
				# change file in current directory
#				if (defined($mapindex = $nameindexmap{$file})) {
					$mapindex = $nameindexmap{$file};
					$self->{_showncontents}[$mapindex]{rcs} = $flags;
#				}
			}
			$screen->listing->show();
			$screen->listing->highlight_on();
		},
		after_finish		=> sub {
			$self->{_rcsjob} = undef;
			$screen->set_deferred_refresh($screen->R_HEADINGS);
			$screen->frame->rcsrunning(RCS_DONE);
		},
	};
	# TODO when a directory is swapped out, the jobs should continue
	# TODO when a directory is cloned, what to do?
	foreach $class (@{$self->RCS}) {
		$fullclass = "App::PFM::Job::$class";
		if ($fullclass->isapplicable($path)) {
			if (defined $self->{_rcsjob}) {
				# The previous job did not yet finish.
				# Kill it and run the command for the entire directory.
				$_pfm->jobhandler->stop($self->{_rcsjob});
				$entry = $path;
			}
			$self->{_rcsjob} = $_pfm->jobhandler->start($class, $entry, $on);
			return;
		}
	}
}

=item preparercscol()

Prepares the 'Version' field in the directory contents by clearing it.

=cut

sub preparercscol {
	my ($self, $file) = @_;
	my $layoutfields = $_pfm->screen->listing->LAYOUTFIELDS;
	if (defined $file and $file->{name} ne '.') {
		$file->{$layoutfields->{'v'}} = '-';
		return;
	}
	foreach (0 .. $#{$self->{_showncontents}}) {
		$self->{_showncontents}[$_]{$layoutfields->{'v'}} = '-';
	}
}

=item dirlookup()

Finds a directory entry by name and returns its index.
Used by apply().

=cut

sub dirlookup {
	# this assumes that the entry will be found
	my ($self, $name, @array) = @_;
	my $found = $#array;
	while ($found >= 0 and $array[$found]{name} ne $name) {
		$found--;
	}
	return $found;
}

=item apply()

In single file mode: applies the supplied function to the current file.
In multiple file mode: applies the supplied function to all selected files
in the current directory.

=cut

sub apply {
	my ($self, $do_this, $special_mode, @args) = @_;
	my ($i, $loopfile, $deleted_index, $count, %nameindexmap);
	if ($_pfm->state->{multiple_mode}) {
		#$self->{_wasquit} = 0;
		#$SIG{QUIT} = \&_catch_quit;
		my $screen = $_pfm->screen;
		my @range = 0 .. $#{$self->{_showncontents}};
		if ($special_mode eq 'reverse') {
			@range = reverse @range;
			# build nameindexmap on dircontents, not showncontents.
			# this is faster than doing a dirlookup() every iteration
			$count = 0;
			%nameindexmap =
				map { $_->{name}, $count++ } @{$self->{_dircontents}};
		}
		foreach $i (@range) {
			$loopfile = $self->{_showncontents}[$i];
			if ($loopfile->{selected} eq M_MARK) {
				# don't give feedback in cOmmand or Your
				if ($special_mode ne 'nofeedback') {
					$screen->at($screen->PATHLINE, 0)->clreol()
						->puts($loopfile->{name})->at($screen->PATHLINE+1, 0);
				}
				$loopfile->apply($do_this, $special_mode, @args);
				# see if the file was lost, and we were deleting.
				# we could also test if return value of File->apply eq 'deleted'
				if (!$loopfile->{nlink} and
					$loopfile->{type} ne 'w' and
					$special_mode eq 'reverse')
				{
					$self->unregister($loopfile);
					$deleted_index = $nameindexmap{$loopfile->{name}};
					splice @{$self->{_dircontents}}, $deleted_index, 1;
					splice @{$self->{_showncontents}}, $i, 1;
				}
			}
			# from perlfunc/system:
#			if ($? == -1) {
#				print "failed to execute: $!\n";
#			}
#			elsif ($? & 127) {
#				printf "child died with signal %d, %s coredump\n",
#				($? & 127),  ($? & 128) ? 'with' : 'without';
#			}
			#last if $self->{_wasquit};
		}
		#$SIG{QUIT} = 'DEFAULT';
		$_pfm->state->{multiple_mode} = 0 if $_pfm->config->{autoexitmultiple};
		$self->checkrcsapplicable() if $_pfm->config->{autorcs};
		$screen->set_deferred_refresh(
			$screen->R_DIRLIST | $screen->R_PATHINFO | $screen->R_FRAME);
	} else {
		$loopfile = $_pfm->browser->currentfile;
		$loopfile->apply($do_this, $special_mode, @args);
		$self->checkrcsapplicable($loopfile->{name})
			if $_pfm->config->{autorcs};
		# see if the file was lost, and we were deleting.
		# we could also test if return value of File->apply eq 'deleted'
		if (!$loopfile->{nlink} and
			$loopfile->{type} ne 'w' and
			$special_mode eq 'reverse')
		{
			$self->unregister($loopfile);
			$deleted_index = $self->dirlookup(
				$loopfile->{name}, @{$self->{_dircontents}});
			splice @{$self->{_dircontents}}, $deleted_index, 1;
			splice @{$self->{_showncontents}}, $i, 1;
		}
	}
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the B<M_*> constants which indicate which characters
are to be used for mark, oldmark and newmark.

=over

=item M_MARK

The character used for marked files.

=item M_OLDMARK

The character used for an oldmark (when a file has been operated on
in multiple mode).

=item M_NEWMARK

The character used for a newmark (when a file has newly been created
in multiple mode).

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
