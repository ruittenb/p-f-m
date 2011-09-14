#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Directory 0.89
#
# Name:			App::PFM::Directory
# Version:		0.89
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-04
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
use App::PFM::Screen qw(:constants);
use App::PFM::Util qw(clearugidcache canonicalize_path basename dirname);
use POSIX qw(getcwd);

use strict;

use constant {
	RCS_DONE		=> 0,
	RCS_RUNNING		=> 1,
	SLOWENTRIES		=> 300,
	D_FILTER		=> 128,  # decide what to display (init @showncontents)
	D_SORT			=> 1024, # sort @dircontents
	D_CONTENTS		=> 2048, # read directory contents from disk
#	D_FILELIST				 # D_CONTENTS + D_SORT + D_FILTER
	D_FSINFO		=> 4096, # filesystem usage data
#	D_ALL					 # D_FSINFO + D_FILELIST
	M_MARK			=> '*',
	M_OLDMARK		=> '.',
	M_NEWMARK		=> '~',
};

use constant D_FILELIST	=> D_CONTENTS | D_SORT | D_FILTER;
use constant D_ALL		=> D_FSINFO | D_FILELIST;

use constant RCS => [
	'Subversion',
	'Cvs',
	'Bazaar',
	'Git',
];

our %EXPORT_TAGS = (
	constants => [ qw(
		D_FILTER
		D_SORT
		D_CONTENTS
		D_FILELIST
		D_FSINFO
		D_ALL
		M_MARK
		M_OLDMARK
		M_NEWMARK
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, string $path)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	 = @_;
	$_pfm					 = $pfm;
	$self->{_path}			 = $path;
	$self->{_rcsjob}		 = undef;
	$self->{_wasquit}		 = undef;
	$self->{_path_mode}		 = 'log';
	$self->{_dircontents}	 = [];
	$self->{_showncontents}	 = [];
	$self->{_selected_nr_of} = {};
	$self->{_total_nr_of}	 = {};
	$self->{_disk}			 = {};
	$self->{_dirty}			 = 0;
}

=item _clone(App::PFM::Directory $original [ , array @args ] )

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
Dotdot mode is taken into account.

=cut

sub _by_sort_mode {
	# note: called directly (not OO-like)
	if ($_pfm->config->{dotdot_mode}) {
		# Oleg Bartunov requested to have . and .. unsorted (always at the top)
		if    ($a->{name} eq '.' ) { return -1 }
		elsif ($b->{name} eq '.' ) { return  1 }
		elsif ($a->{name} eq '..') { return -1 }
		elsif ($b->{name} eq '..') { return  1 }
	}
	return _sort_multilevel($_pfm->state->sort_mode, $a, $b);
}

=item _sort_multilevel(string $sort_mode, App::PFM::File $a, App::PFM::File $b)

Recursively sorts two directory entries according to the selected
sort mode string (multilevel).

=cut

sub _sort_multilevel {
	# note: called directly (not OO-like)
	my ($sort_mode, $a, $b) = @_;
	return 0 unless length $sort_mode;
	return
		_sort_singlelevel(substr($sort_mode, 0, 1), $a, $b) ||
		_sort_multilevel( substr($sort_mode, 1),    $a, $b);
}

=item _sort_singlelevel(char $sort_mode, App::PFM::File $a, App::PFM::File $b)

Sorts two directory entries according to the selected sort mode
character (one level).

=cut

sub _sort_singlelevel {
	# note: called directly (not OO-like)
	my ($sort_mode, $a, $b) = @_;
	my ($exta, $extb);
	for ($sort_mode) {
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
		/u/  and return		$a->{uid}		cmp		$b->{uid};
		/U/  and return		$b->{uid}		cmp		$a->{uid};
		/g/  and return		$a->{gid}		cmp		$b->{gid};
		/G/  and return		$b->{gid}		cmp		$a->{gid};
		/l/  and return		$a->{nlink}		<=>		$b->{nlink};
		/L/  and return		$b->{nlink}		<=>		$a->{nlink};
		/i/  and return		$a->{inode}		<=>		$b->{inode};
		/I/  and return		$b->{inode}		<=>		$a->{inode};
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
			 if ($a->{name} =~ /^(.*)(\.[^\.]+)$/) {
				 $exta = $2."\0377".$1;
			 } else {
				 $exta = "\0377".$a->{name};
			 }
			 if ($b->{name} =~ /^(.*)(\.[^\.]+)$/) {
				 $extb = $2."\0377".$1;
			 } else {
				 $extb = "\0377".$b->{name};
			 }
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

=item _init_dircount()

Initializes the total number of entries of each type in the current
directory by zeroing them out.

=cut

sub _init_dircount {
	my ($self) = @_;
	%{$self->{_selected_nr_of}} =
		%{$self->{_total_nr_of}} =
			( d=>0, '-'=>0, l=>0, c=>0, b=>0, D=>0, P=>0,
			  p=>0, 's'=>0, n=>0, w=>0, bytes => 0 );
}

=item _countcontents(array @entries)

Counts the total number of entries of each type in the current directory.

=cut

sub _countcontents {
	my ($self, @entries) = @_;
	$self->_init_dircount();
	foreach my $i (0..$#entries) {
		$self->{_total_nr_of   }{$entries[$i]{type}}++;
		$self->{_selected_nr_of}{$entries[$i]{type}}++
			if $entries[$i]{selected} eq M_MARK;
	}
}

=item _readcontents()

Reads the entries in the current directory and performs a stat() on them.

=cut

sub _readcontents {
	my ($self) = @_;
	my ($entry, $file);
	my @allentries    = ();
	my @white_entries = ();
	my $screen        = $_pfm->screen;
	# TODO stop jobs here
	clearugidcache();
	$self->_init_dircount();
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
	$screen->set_deferred_refresh(R_MENU | R_HEADINGS);
	$self->checkrcsapplicable() if $_pfm->config->{autorcs};
	return $self->{_dircontents};
}

=item _sortcontents()

Sorts the directory's contents according to the selected sort mode.

=cut

sub _sortcontents {
	my ($self) = @_;
	@{$self->{_dircontents}} = sort _by_sort_mode @{$self->{_dircontents}};
}

=item _filtercontents()

Filters the directory contents according to the filter modes
(displays or hides dotfiles and whiteouts).

=cut

sub _filtercontents {
	my ($self) = @_;
	@{$self->{_showncontents}} = grep {
		$_pfm->state->{dot_mode}   || $_->{name} =~ /^(\.\.?|[^\.].*)$/ and
		$_pfm->state->{white_mode} || $_->{type} ne 'w'
	} @{$self->{_dircontents}};
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

=item path( [ string $nextdir [, bool $swapping [, string $direction ] ] ] )

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

=item dircontents( [ arrayref $dircontents ] )

Getter/setter for the $_dircontents member variable, which points to
the complete array of files in the directory.

=cut

sub dircontents {
	my ($self, $value) = @_;
	$self->{_dircontents} = $value if defined $value;
	return $self->{_dircontents};
}

=item showncontents( [ arrayref $showncontents ] )

Getter/setter for the $_showncontents member variable, which points to
the array of the files shown on-screen.

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

=item mountpoint( [ string $mountpoint ] )

Getter/setter for the mountpoint on which the current directory is situated.

=cut

sub mountpoint {
	my ($self, $value) = @_;
	$self->{_disk}{mountpoint} = $value if defined $value;
	return $self->{_disk}{mountpoint};
}

=item device( [ string $device ] )

Getter/setter for the device on which the current directory is situated.

=cut

sub device {
	my ($self, $value) = @_;
	$self->{_disk}{device} = $value if defined $value;
	return $self->{_disk}{device};
}

=item path_mode( [ string $path_mode ] )

Getter/setter for the path mode setting ('phys' or 'log')

=cut

sub path_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_path_mode} = $value;
		$self->{_path} = getcwd() if $self->{_path_mode} eq 'phys';
		$_pfm->screen->set_deferred_refresh(R_FOOTER | R_PATHINFO);
	}
	return $self->{_path_mode};
}

##########################################################################
# public subs

=item prepare( [ string $path ] )

Prepares the contents of this directory object. Can be used if this
state should not be displayed on-screen right away.

=cut

sub prepare {
	my ($self, $path) = @_;
	$self->path_mode($_pfm->config->{path_mode});
	if (defined $path) {
		$self->{_path} = $path;
	}
	$self->_init_filesystem_info();
	$self->_readcontents();
	$self->_sortcontents();
	$self->_filtercontents();
	$self->{_dirty} = 0;
}

=item chdir(string $nextdir [, bool $swapping [, string $direction ] ] )

Tries to change the current working directory, if necessary using B<CDPATH>.
If successful, it stores the previous state in App::PFM::Application->_states
and executes the 'chdirautocmd' from the F<.pfmrc> file.

The I<swapping> argument can be passed as true to prevent undesired pathname
parsing during pfm's B<F7> command.

The I<direction> argument can be 'up' (when changing to a parent directory),
'down' (when descending into a directory) or empty (when making a jump) and
will determine where the cursor will be positioned in the new directory (at
the previous directory when moving up, at '..' when descending, and at '.'
when making a jump).

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
			$screen->set_deferred_refresh(R_SCREEN);
		} else {
			$nextpos = $direction eq 'up'
				? basename($prevdir)
				: $direction eq 'down' ? '..' : '.';
			$_pfm->browser->position_at($nextpos);
			$_pfm->browser->baseindex(0);
			$screen->set_deferred_refresh(R_CHDIR);
			$self->set_dirty(D_ALL);
		}
		$chdirautocmd = $_pfm->config->{chdirautocmd};
		system("$chdirautocmd") if length($chdirautocmd);
	}
	return $success;
}

=item addifabsent(hashref { entry => string $filename, white => char
$iswhite, mark => char $mark, refresh => bool $refresh } )

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
			$_pfm->screen->set_deferred_refresh(R_LISTING);
			$self->set_dirty(D_FILTER | D_SORT);
		}
	}
}

=item add(hashref { entry => string $filename, white => char
$iswhite, mark => char $mark, refresh => bool $refresh } )

Adds the entry as file to the directory. Also calls register().

=cut

sub add {
	my ($self, %o) = @_; # ($entry, $white, $mark, $refresh);
	my $file = new App::PFM::File(%o, parent => $self->{_path});
	push @{$self->{_dircontents}}, $file;
	$self->register($file);
	if ($o{refresh}) {
		$_pfm->screen->set_deferred_refresh(R_LISTING);
		$self->set_dirty(D_FILTER | D_SORT);
	}
}

=item register(App::PFM::File $file)

Adds the file to the internal (total and marked) counters.

=cut

sub register {
	my ($self, $entry) = @_;
	$self->{_total_nr_of}{$entry->{type}}++;
	if ($entry->{selected} eq M_MARK) {
		$self->register_include($entry);
	}
	$_pfm->screen->set_deferred_refresh(R_DISKINFO);
}

=item unregister(App::PFM::File $file)

Removes the file from the internal (total and marked) counters.

=cut

sub unregister {
	my ($self, $entry) = @_;
	my $prevmark;
	$self->{_total_nr_of}{$entry->{type}}--;
	if ($entry->{selected} eq M_MARK) {
		$prevmark = $self->register_exclude($entry);
	}
	$_pfm->screen->set_deferred_refresh(R_DISKINFO);
	return $prevmark;
}

=item include(App::PFM::File $file)

Marks a file. Updates the internal (marked) counters.

=cut

sub include {
	my ($self, $entry) = @_;
	$self->register_include($entry) if ($entry->{selected} ne M_MARK);
	$entry->{selected} = M_MARK;
}

=item exclude(App::PFM::File $file [, char $to_mark ] )

Removes a file's mark, or replaces it with I<to_mark>. Updates the
internal (marked) counters.

=cut

sub exclude {
	my ($self, $entry, $to_mark) = @_;
	my $prevmark = $entry->{selected};
	$self->register_exclude($entry) if ($entry->{selected} eq M_MARK);
	$entry->{selected} = $to_mark || ' ';
	return $prevmark;
}

=item register_include(App::PFM::File $file)

Adds a file to the counters of marked files.

=cut

sub register_include {
	my ($self, $entry) = @_;
	$self->{_selected_nr_of}{$entry->{type}}++;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} += $entry->{size};
	$_pfm->screen->set_deferred_refresh(R_DISKINFO);
}

=item register_exclude(App::PFM::File $file)

Removes a file from the counters of marked files.

=cut

sub register_exclude {
	my ($self, $entry) = @_;
	$self->{_selected_nr_of}{$entry->{type}}--;
	$entry->{type} =~ /-/ and $self->{_selected_nr_of}{bytes} -= $entry->{size};
	$_pfm->screen->set_deferred_refresh(R_DISKINFO);
}

=item set_dirty(int $flag_bits)

Flags that this directory needs to be updated. The B<D_*>
constants (see below) may be used to specify which aspect.

=cut

sub set_dirty {
	my ($self, $bits) = @_;
	$self->{_dirty} |= $bits;
}

=item unset_dirty(int $flag_bits)

Removes the flag that this directory needs to be updated. The B<D_*>
constants (see below) may be used to specify which aspect.

=cut

sub unset_dirty {
	my ($self, $bits) = @_;
	$self->{_dirty} &= ~$bits;
}

=item refresh()

Refreshes the aspects of the directory that have been flagged as dirty.

=cut

sub refresh {
	my ($self)  = @_;
	my $browser = $_pfm->browser;
	my $dirty   = $self->{_dirty};
	$self->{_dirty} = 0;

	if ($dirty & D_FILELIST) { # any of the flags
		# first time round 'currentfile' is undefined
		if (defined $browser->currentfile) {
			# TODO we should handle this with an event.
			$browser->position_at($browser->currentfile->{name});
		}
		# next line works because $screen->refresh() will re-examine
		# the _deferred_refresh flags after the $directory->refresh().
		#
		$_pfm->screen->set_deferred_refresh(R_LISTING);
	}
	# now refresh individual elements
	if ($dirty & D_FSINFO) {
		$self->_init_filesystem_info();
	}
	if ($dirty & D_CONTENTS) {
		$self->_readcontents();
	}
	if ($dirty & D_SORT) {
		$self->_sortcontents();
	}
	if ($dirty & D_FILTER) {
		$self->_filtercontents();
	}
}

=item checkrcsapplicable( [ string $path ] )

Checks if any rcs jobs are applicable for this directory,
and starts them.

=cut

sub checkrcsapplicable {
	my ($self, $entry) = @_;
	my ($class, $fullclass);
	my $path   = $self->{_path};
	my $screen = $_pfm->screen;
	$entry = defined $entry ? $entry : $path;
	my $on_after_job_start = sub {
		# next line needs to provide a '1' argument because
		# $self->{_rcsjob} has not yet been set
		$screen->set_deferred_refresh(R_HEADINGS);
		$screen->frame->rcsrunning(RCS_RUNNING);
	};
	my $on_after_job_receive_data = sub {
		my $event = shift;
		my $job   = $event->{origin};
		my ($flags, $file) = @{$event->{data}};
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
#			# if there was a change in a subdir, then show M on currentdir
#			$mapindex = $nameindexmap{'.'};
#			# find highest prio marker
#			$oldval = $self->{_showncontents}[$mapindex]{rcs};
#			$self->{_showncontents}[$mapindex]{rcs} =
#				$job->rcsmax($oldval, 'M');
		} else {
			# change file in current directory
#			if (defined($mapindex = $nameindexmap{$file})) {
				$mapindex = $nameindexmap{$file};
				$self->{_showncontents}[$mapindex]{rcs} = $flags;
#			}
		}
		# TODO only show if this directory is on-screen (is_main).
		$screen->listing->show();
		$screen->listing->highlight_on();
	};
	my $on_after_job_finish = sub {
		$self->{_rcsjob} = undef;
		$screen->set_deferred_refresh(R_HEADINGS);
		$screen->frame->rcsrunning(RCS_DONE);
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
			$self->{_rcsjob} = $_pfm->jobhandler->start($class, $entry, {
				after_job_start			=> $on_after_job_start,
				after_job_receive_data	=> $on_after_job_receive_data,
				after_job_finish		=> $on_after_job_finish,
			});
			return;
		}
	}
}

=item preparercscol(App::PFM::File $file)

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

=item dirlookup(string $filename, array @dircontents)

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

=item apply(coderef $do_this, string $special_mode, array @args)

In single file mode: applies the supplied function to the current file.
In multiple file mode: applies the supplied function to all selected files
in the current directory.

If I<special_mode> equals 'delete', the directory is processed in
reverse order. This is important when deleting files.

If I<special_mode> does not equal 'nofeedback', the filename of the file
being processed will be displayed on the second line of the screen.

=cut

sub apply {
	my ($self, $do_this, $special_mode, @args) = @_;
	my ($i, $loopfile, $deleted_index, $count, %nameindexmap);
	if ($_pfm->state->{multiple_mode}) {
		#$self->{_wasquit} = 0;
		#local $SIG{QUIT} = \&_catch_quit;
		my $screen = $_pfm->screen;
		my @range = 0 .. $#{$self->{_showncontents}};
		if ($special_mode eq 'delete') {
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
					$special_mode eq 'delete')
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
		$_pfm->state->{multiple_mode} = 0 if $_pfm->config->{autoexitmultiple};
		$self->checkrcsapplicable() if $_pfm->config->{autorcs};
		$screen->set_deferred_refresh(R_LISTING | R_PATHINFO | R_FRAME);
	} else {
		$loopfile = $_pfm->browser->currentfile;
		$loopfile->apply($do_this, $special_mode, @args);
		$self->checkrcsapplicable($loopfile->{name})
			if $_pfm->config->{autorcs};
		# see if the file was lost, and we were deleting.
		# we could also test if return value of File->apply eq 'deleted'
		if (!$loopfile->{nlink} and
			$loopfile->{type} ne 'w' and
			$special_mode eq 'delete')
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

This package provides the B<D_*> constants which indicate
which aspects of the directory object need to be refreshed.
They can be imported with C<use App::PFM::Directory qw(:constants)>.

=over

=item D_FILTER

The directory contents should be filtered again.

=item D_SORT

The directory contents should be sorted again.

=item D_CONTENTS

The directory contents should be updated from disk.

=item D_FILELIST

Convenience alias for a combination of all of the above.

=item D_FSINFO

The filesystem usage information should be updated from disk.

=item D_ALL

Convenience alias for a combination of all of the above.

=back

A refresh need for an aspect of the directory may be flagged by
providing one or more of these constants to set_dirty(), I<e.g.>

	$directory->set_dirty(D_SORT);

The actual refresh will be performed on calling:

	$directory->refresh();

This will also reset the flags.

In addition, this package provides the B<M_*> constants which
indicate which characters are to be used for mark, oldmark and newmark.
They can be imported with C<use App::PFM::Directory qw(:constants)>.

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
