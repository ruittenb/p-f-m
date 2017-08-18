#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Directory 1.14
#
# Name:			App::PFM::Directory
# Version:		1.14
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2017-08-18
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

use App::PFM::Job::Bazaar;
use App::PFM::Job::Cvs;
use App::PFM::Job::Git;
use App::PFM::Job::Mercurial;
use App::PFM::Job::Subversion;
use App::PFM::File;
use App::PFM::Screen qw(:constants);
use App::PFM::Util qw(clearugidcache canonicalize_path basename dirname);
use POSIX qw(getcwd);

use strict;
use locale;

use constant {
	RCS_DONE		=> 0,
	RCS_RUNNING		=> 1,
	SLOWENTRIES		=> 300,
	D_FILTER		=> 128,  # decide what to display (init @showncontents)
	D_SORT			=> 256,  # sort @dircontents
	D_CONTENTS		=> 512,  # read directory contents from disk
	D_SMART			=> 1024, # make D_CONTENTS smart (i.e. smart refresh)
#	D_FILELIST				 # D_CONTENTS + D_SORT + D_FILTER
	D_CHDIR			=> 2048, # filesystem usage data
#	D_ALL					 # D_CHDIR + D_FILELIST
	M_MARK			=> '*',
	M_OLDMARK		=> '.',
	M_NEWMARK		=> '~',
};

use constant D_FILELIST			=> D_SORT | D_FILTER | D_CONTENTS;
use constant D_FILELIST_SMART	=> D_SORT | D_FILTER | D_CONTENTS | D_SMART;
use constant D_ALL				=> D_CHDIR | D_FILELIST;

use constant RCS => [ qw(
	Subversion
	Mercurial
	Cvs
	Bazaar
	Git
) ];

our %EXPORT_TAGS = (
	constants => [ qw(
		D_FILTER
		D_SORT
		D_CONTENTS
		D_SMART
		D_FILELIST
		D_FILELIST_SMART
		D_CHDIR
		D_ALL
		M_MARK
		M_OLDMARK
		M_NEWMARK
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

my ($_pfm); # file scope

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm, App::PFM::Screen $screen,
App::PFM::Config $config, App::PFM::OS $os, App::PFM::JobHandler $jobhandler,
string $path)

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen, $config, $os, $jobhandler, $path) = @_;
	App::PFM::File::set_app($pfm);
	$_pfm					 = $pfm;
	$self->{_screen}         = $screen;
	$self->{_config}         = $config;
	$self->{_os}             = $os;
	$self->{_jobhandler}     = $jobhandler;
	$self->{_path}			 = $path;
	$self->{_logicalpath}	 = $path;
	$self->{_rcsjob}		 = undef;
	$self->{_wasquit}		 = undef;
	$self->{_path_mode}		 = 'log';
	$self->{_ignore_mode}	 = 0;
	$self->{_dircontents}	 = [];
	$self->{_showncontents}	 = [];
	$self->{_marked_nr_of}   = {};
	$self->{_total_nr_of}	 = {};
	$self->{_disk}			 = {};
	$self->{_dirty}			 = 0;

	$self->_install_event_handlers();
	return;
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
	$self->{_marked_nr_of}   = { %{$original->{_marked_nr_of}	} };
	$self->{_total_nr_of}	 = { %{$original->{_total_nr_of}	} };
	$self->{_disk}			 = { %{$original->{_disk}			} };

	# Any running rcs job has got event handlers pointing to the original
	# Directory object (i.e., not to our event handlers). Remove the job
	# number from the clone.
	$self->{_rcsjob}         = undef;

	$self->_install_event_handlers();
	return;
}

=item _install_event_handlers()

Installs listeners for the events 'after_set_color_mode' (fired
by App::PFM::Screen) and 'after_change_formatlines' (fired by
App::PFM::Screen::Listing), that require reformatting of the File objects.

=cut

sub _install_event_handlers {
	my ($self) = @_;
	$self->{_on_after_change_formatlines} =
	$self->{_on_after_set_color_mode}     = sub {
		$self->reformat();
	};
	$self->{_screen}->register_listener(
		'after_set_color_mode',     $self->{_on_after_set_color_mode});
	$self->{_screen}->listing->register_listener(
		'after_change_formatlines', $self->{_on_after_change_formatlines});
	return;
}

=item _by_sort_mode()

Sorts two directory entries according to the selected sort mode.
Dotdot mode is taken into account.

=cut

sub _by_sort_mode {
	my ($self) = @_;
	if ($self->{_config}->{dotdot_mode}) {
		# Oleg Bartunov requested to have . and .. unsorted (always at the top)
		if    ($a->{name} eq '.' ) { return -1 }
		elsif ($b->{name} eq '.' ) { return  1 }
		elsif ($a->{name} eq '..') { return -1 }
		elsif ($b->{name} eq '..') { return  1 }
	}
	return $self->_sort_multilevel($_pfm->state->sort_mode);
}

=item _sort_multilevel(string $sort_mode)

Recursively sorts two directory entries according to the selected
sort mode string (multilevel).

=cut

sub _sort_multilevel {
	my ($self, $sort_mode) = @_;
	return 0 unless length $sort_mode;
	return
		$self->_sort_singlelevel(substr($sort_mode, 0, 1)) ||
		$self->_sort_multilevel( substr($sort_mode, 1));
}

=item _sort_singlelevel(char $sort_mode)

Sorts two directory entries according to the selected sort mode
character (one level).

=cut

sub _sort_singlelevel {
	my ($self, $sort_mode) = @_;
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
		/u/  and return		$a->{user}		cmp		$b->{user};
		/U/  and return		$b->{user}		cmp		$a->{user};
		/g/  and return		$a->{group}		cmp		$b->{group};
		/G/  and return		$b->{group}		cmp		$a->{group};
		/w/  and return		$a->{uid}		<=>		$b->{uid};
		/W/  and return		$b->{uid}		<=>		$a->{uid};
		/h/  and return		$a->{gid}		<=>		$b->{gid};
		/H/  and return		$b->{gid}		<=>		$a->{gid};
		/l/  and return		$a->{nlink}		<=>		$b->{nlink};
		/L/  and return		$b->{nlink}		<=>		$a->{nlink};
		/i/  and return		$a->{inode}		<=>		$b->{inode};
		/I/  and return		$b->{inode}		<=>		$a->{inode};
		/v/  and return		$a->{rcs}		cmp		$b->{rcs};
		/V/  and return		$b->{rcs}		cmp		$a->{rcs};
		/t/  and do {
				return  0 if ($a->{type} eq $b->{type});
				return -1 if ($a->{type} eq 'd');
				return  1 if ($b->{type} eq 'd');
				return        $a->{type} cmp $b->{type};
		};
		/T/  and do {
				return  0 if ($a->{type} eq $b->{type});
				return -1 if ($b->{type} eq 'd');
				return  1 if ($a->{type} eq 'd');
				return        $b->{type} cmp $a->{type};
		};
		/p/  and do {
				return  0 if ($a->{mode} eq  $b->{mode});
				return        $a->{mode} cmp $b->{mode};
		};
		/P/  and do {
				return  0 if ($a->{mode} eq  $b->{mode});
				return        $b->{mode} cmp $a->{mode};
		};
		/\*/ and do {
				return  0 if ($a->{mark} eq $b->{mark});
				return -1 if ($a->{mark} eq M_MARK   );
				return  1 if ($b->{mark} eq M_MARK   );
				return -1 if ($a->{mark} eq M_NEWMARK);
				return  1 if ($b->{mark} eq M_NEWMARK);
				return -1 if ($a->{mark} eq M_OLDMARK);
				return  1 if ($b->{mark} eq M_OLDMARK);
				return        $a->{mark} cmp $b->{mark};
		};
		/[ef]/i and do {
			$exta = $extb = '';
			if ($a->{name} =~ /^.*(\.[^\.]+)$/) {
				$exta = $1;
			}
			if ($b->{name} =~ /^.*(\.[^\.]+)$/) {
				$extb = $1;
			}
			/e/ and return    $exta  cmp    $extb;
			/E/ and return    $extb  cmp    $exta;
			/f/ and return lc($exta) cmp lc($extb);
			/F/ and return lc($extb) cmp lc($exta);
		};
	}
	return;
}

=item _init_filesystem_info()

Determines the current filesystem usage and stores it in an internal hash.

=cut

sub _init_filesystem_info {
	my ($self) = @_;
	my (@dflist, @mountlist, $mountpoint, @mountinfo, $fstype, $layers, @layers);

	chop (@dflist = $self->{_os}->df($self->{_path}));
	shift @dflist; # skip header
	@{$self->{_disk}}{qw/device total used avail/} = split (/\s+/, $dflist[0]);
	$dflist[0] =~ /(\S*)$/;
	$mountpoint = $1;
	$self->{_disk}{mountpoint} = $mountpoint;

	chop (@mountlist = $self->{_os}->backtick('mount'));
	# "none on /dev/pts type devpts (rw,noexec,nosuid,gid=5,mode=0620)"
	@mountinfo = grep { /^\S+\s+on\s+(\Q$mountpoint\E)\s+/ } @mountlist;

	# For aufs. TODO move this to App::PFM::Filesystem
	# Linux:
	#    "none on /mnt/overlay type aufs (rw,br:/mnt/upper:/mnt/intermediate:/mnt/lower)"
	# Darwin:
	#    "/dev/disk0s3 on / (hfs, local, journaled)"
	($fstype) = $mountinfo[0] =~ /\Q$mountpoint\E\s+(?:type\s+|\()(\S+)/;
	($layers) = $mountinfo[0] =~ /[\(,]br:([^\)]+)/;
	@layers = split(/:/, $layers) if defined $layers;
#	$self->{_disk}{mountinfo} = $mountinfo[0];
	$self->{_disk}{fstype} = $fstype;
	$self->{_disk}{layers} = [ @layers ];

	return $self->{_disk};
}

=item _init_dircount()

Initializes the total number of entries of each type in the current
directory by zeroing them out.

=cut

sub _init_dircount {
	my ($self) = @_;
	%{$self->{_marked_nr_of}} =
		%{$self->{_total_nr_of}} =
			( d=>0, '-'=>0, l=>0, c=>0, b=>0, D=>0, P=>0,
			  p=>0, 's'=>0, n=>0, w=>0, bytes => 0 );
	return;
}

=item _countcontents(array @entries)

Counts the total number of entries of each type in the current directory.

=cut

sub _countcontents {
	my ($self, @entries) = @_;
	$self->_init_dircount();
	foreach my $i (0..$#entries) {
		$self->{_total_nr_of }{$entries[$i]{type}}++;
		$self->{_marked_nr_of}{$entries[$i]{type}}++
			if $entries[$i]{mark} eq M_MARK;
	}
	return;
}

=item _readcontents(bool $smart)

Reads the entries in the current directory and performs a stat() on them.

If I<smart> is false, the directory is read fresh. If true, the directory
is refreshed but the marks are retained.

=cut

sub _readcontents {
	my ($self, $smart) = @_;
	my ($file, %namemarkmap, $counter, $interrupted, $interrupt_key, $layer);
	my @allentries        = ();
	my @white_entries     = ();
	my %white_entries     = ();
	my @new_white_entries = ();
	my $screen            = $self->{_screen};
	# TODO stop jobs here?
	clearugidcache();
	$self->_init_dircount();
	%namemarkmap = map { $_->{name}, $_->{mark}; } @{$self->{_dircontents}};
	$self->{_dircontents}   = [];
	$self->{_showncontents} = [];
	# don't use '.' as the directory path to open: we may be just
	# prepare()ing this object without actually entering the directory
	if (opendir my $CURRENT, $self->{_path}) {
		@allentries = readdir $CURRENT;
		closedir $CURRENT;
		# should be something like $self->{_filesystem}->listwhite()
		if ($self->{_disk}{fstype} eq 'aufs') {
			foreach $layer (@{$self->{_disk}{layers}}) {
				@new_white_entries =
					grep { !/^\.wh\./ }
					map { s!\Q$layer\E/\.wh\.!!; $_ }
					glob("$layer/.wh.*");
				push @white_entries, @new_white_entries;
			}
			# remove duplicates (we may have whiteout entries in multiple layers)
			@white_entries{@white_entries} = ();
			@white_entries = keys %white_entries;
		} else {
			# chop newlines
			@white_entries = map { chop; $_ } $self->{_os}->listwhite($self->{_path});
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
	$counter = $#allentries + SLOWENTRIES/2; # Prevent "0" from being printed
	STAT_ENTRIES: foreach my $entry (@allentries) {
		# have the mark cleared on first stat with ' '
		$self->add({
			entry     => $entry,
			skip_stat => $interrupted,
			white     => '',
			mark      => $smart ? $namemarkmap{$entry} : ' '
		});
		unless (--$counter % SLOWENTRIES) {
			$screen->at(0,0)->putmessage(
				sprintf('Please Wait [%d]', $counter / SLOWENTRIES))->clreol();
		}
		# See if a new key was pressed.
		if (!defined($interrupt_key) and $screen->pending_input()) {
			# See if it was "Escape".
			if (($interrupt_key = $screen->getch()) eq "\e") {
				# It was. Flag "interrupted" for the rest of the loop.
				$interrupted = 1;
			} else {
				# It was not. Put it back on the input queue.
				$screen->stuff_input($interrupt_key);
			}
		}
	}
	foreach my $entry (@white_entries) {
		$self->add({
			entry => $entry,
			white => 'w',
			mark  => $smart ? $namemarkmap{$entry} : ' '
		});
	}
	$screen->set_deferred_refresh(R_MENU | R_HEADINGS);
	$self->checkrcsapplicable() if $self->{_config}{autorcs};
	return $self->{_dircontents};
}

=item _sortcontents()

Sorts the directory's contents according to the selected sort mode.

=cut

sub _sortcontents {
	my ($self) = @_;
	@{$self->{_dircontents}} =
		sort { $self->_by_sort_mode } @{$self->{_dircontents}};
	return;
}

=item _filtercontents()

Filters the directory contents according to the filter modes
(displays or hides dotfiles and whiteouts; custom filename filter).

=cut

sub _filtercontents {
	my ($self) = @_;
	@{$self->{_showncontents}} = grep {
		$_pfm->state->{dot_mode}         || $_->{name} =~ /^(\.\.?|[^\.].*)$/ and
		$_pfm->state->{white_mode}       || $_->{type} ne 'w' and
		$_pfm->state->{file_filter_mode} || !exists($_pfm->config->{file_filter}{$_->{name}})
	} @{$self->{_dircontents}};
	return;
}

=item _catch_quit()

Catches terminal quit signals (SIGQUIT).

=cut

sub _catch_quit {
	my ($self) = @_;
	$self->{_wasquit} = 1;
	$SIG{QUIT} = \&_catch_quit;
	return;
}

##########################################################################
# constructor, getters and setters

=item destroy()

Unregisters our 'after_change_formatlines' and 'after_set_color_mode'
event listeners with the App::PFM::Screen and App::PFM::Screen::Listing
objects. This removes the references that they have to us, readying the
Directory object for garbage collection.

=cut

sub destroy {
	my ($self) = @_;
	my $screen = $self->{_screen};
	if (defined $screen) {
		$screen->unregister_listener(
			'after_set_color_mode',
			$self->{_on_after_set_color_mode});
		if (defined $screen->listing) {
			$screen->listing->unregister_listener(
				'after_change_formatlines',
				$self->{_on_after_change_formatlines});
		}
	}
#	$self->stop_any_rcsjob();
	return;
}

=item path()

Getter for the current directory path. Setting the current
directory should be done through App::PFM::Directory::chdir() or
App::PFM::Directory::prepare().

=cut

sub path {
	my ($self) = @_;
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

=item marked_nr_of()

Getter for the hash which keeps track of how many directory entities
of each type have been marked.

=cut

sub marked_nr_of {
	return $_[0]->{_marked_nr_of};
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
		if ($self->{_path_mode} eq 'phys') {
			$self->{_path} = getcwd();
		} else {
			$self->{_path} = $self->{_logicalpath};
		}
		$self->{_screen}->set_deferred_refresh(R_FOOTER | R_PATHINFO);
	}
	return $self->{_path_mode};
}

=item ignore_mode( [ bool $ignore_mode ] )

Getter/setter for the ignore mode setting.

=cut

sub ignore_mode {
	my ($self, $value) = @_;
	if (defined $value) {
		$self->{_ignore_mode} = $value;
		$self->{_screen}->set_deferred_refresh(R_FOOTER);
		$self->preparercscol();
		$self->checkrcsapplicable();
	}
	return $self->{_ignore_mode};
}

##########################################################################
# public subs

=item prepare( [ string $path ] )

Prepares the contents of this directory object. Can be used if this
state should not be displayed on-screen right away.

=cut

sub prepare {
	my ($self, $path) = @_;
	$self->path_mode($self->{_config}{path_mode});
	if (defined $path) {
		$self->{_path}        = $path;
		$self->{_logicalpath} = $path;
	}
	$self->_init_filesystem_info();
	$self->_readcontents(); # prepare(), so no need for D_SMART
	$self->_sortcontents();
	$self->_filtercontents();
	$self->{_dirty} = 0;
	return;
}

=item chdir(string $nextdir [, string $direction [, bool $no_save_prev ] ] )

Tries to change the current working directory, if necessary using B<CDPATH>.
If successful, it stores the previous state in App::PFM::Application->_states
and executes the 'chdirautocmd' from the F<.pfmrc> file.

The I<direction> argument can be 'up' (when changing to a parent directory),
'down' (when descending into a directory) or empty (when making a jump) and
will determine where the cursor will be positioned in the new directory (at
the previous directory when moving up, at '..' when descending, and at '.'
when making a jump).

The I<no_save_prev> argument can be used to indicate that the current
state should not be saved to the "previous" state (B<F2> command).

=cut

sub chdir {
	my ($self, $nextdir, $direction, $no_save_prev) = @_;
	my ($success, $chdirautocmd, $nextpos);
	my $screen = $self->{_screen};
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
	$self->fire(App::PFM::Event->new({
		name => 'before_change_directory',
		type => 'soft',
		# TODO use this event to flag to Application that the S_MAIN is to be
		# saved in S_PREV.
	}));
	if ($success = chdir $nextdir and $nextdir ne $prevdir) {
		# store the cursor position in the state
		$_pfm->state->{_position}  = $_pfm->browser->currentfile->{name};
		$_pfm->state->{_baseindex} = $_pfm->browser->baseindex;
		unless ($no_save_prev) { # TODO move this to Application?
			# Note that the clone does not inherit the rcs job number.
			$_pfm->state('S_PREV', $_pfm->state->clone());
		}
		# Stop the rcs job. We don't need it any more.
		$self->stop_any_rcsjob();
		# In 'phys' mode: find the physical name of the directory.
		if ($self->{_path_mode} eq 'phys') {
			$self->{_path} = getcwd();
		} else {
			$self->{_path} = $nextdir;
		}
		$self->{_logicalpath} = $self->{_path};
		# restore the cursor position
#		if ($swapping) {
#			$_pfm->browser->position_at($_pfm->state->{_position});
#			$_pfm->browser->baseindex(  $_pfm->state->{_baseindex});
#			$screen->set_deferred_refresh(R_SCREEN);
#		} else {
			$nextpos = $direction eq 'up'
				? basename($prevdir)
				: $direction eq 'down' ? '..' : '.';
			$_pfm->browser->position_at($nextpos);
			$_pfm->browser->baseindex(0);
			$screen->set_deferred_refresh(R_CHDIR);
			$self->set_dirty(D_ALL);
#		}
		$chdirautocmd = $self->{_config}{chdirautocmd};
		system("$chdirautocmd") if length($chdirautocmd);
	}
	return $success;
}

=item addifabsent(hashref { entry => string $filename, white => char
$iswhite, mark => char $mark, refresh => bool $refresh } )

Checks if the file is not yet in the directory. If not, add()s it.

=cut

sub addifabsent {
	my ($self, $options) = @_;
	my $findindex = 0;
	my $dircount  = $#{$self->{_dircontents}};
	my $file;
	while ($findindex <= $dircount and
		$options->{entry} ne ${$self->{_dircontents}}[$findindex]{name})
	{
		$findindex++;
	}
	if ($findindex > $dircount) {
		$self->add($options);
	} else {
		$file = ${$self->{_dircontents}}[$findindex];
		$self->unregister($file);
		# copy $white from caller, it may be a whiteout.
		# copy $mark  from file (preserve).
		$file->stat_entry($file->{name}, $options->{white}, $file->{mark});
		$self->register($file);
		$self->set_dirty(D_FILTER | D_SORT);
		# flag screen refresh
		if ($options->{refresh}) {
			$self->{_screen}->set_deferred_refresh(R_LISTING);
		}
	}
	return;
}

=item add(hashref { entry => string $filename, white => char
$iswhite, mark => char $mark, refresh => bool $refresh } )

Adds the entry as file to the directory. Also calls register().

=cut

sub add {
	my ($self, $options) = @_;
	$options->{parent}   = $self->{_path};
	my $file             = App::PFM::File->new($options);
	push @{$self->{_dircontents}}, $file;
	$self->register($file);
	$self->set_dirty(D_FILTER | D_SORT);
	if ($options->{refresh}) {
		$self->{_screen}->set_deferred_refresh(R_LISTING);
	}
	return;
}

=item register(App::PFM::File $file)

Adds the file to the internal (total and marked) counters.

=cut

sub register {
	my ($self, $entry) = @_;
	$self->{_total_nr_of}{$entry->{type}}++;
	if ($entry->{mark} eq M_MARK) {
		$self->register_include($entry);
	}
	$self->{_screen}->set_deferred_refresh(R_DISKINFO);
	return;
}

=item unregister(App::PFM::File $file)

Removes the file from the internal (total and marked) counters.

=cut

sub unregister {
	my ($self, $entry) = @_;
	my $prevmark;
	$self->{_total_nr_of}{$entry->{type}}--;
	if ($entry->{mark} eq M_MARK) {
		$prevmark = $self->register_exclude($entry);
	}
	$self->{_screen}->set_deferred_refresh(R_DISKINFO);
	return $prevmark;
}

=item include(App::PFM::File $file)

Marks a file. Updates the internal (marked) counters.

=cut

sub include {
	my ($self, $entry) = @_;
	$self->register_include($entry) if ($entry->{mark} ne M_MARK);
	$entry->{mark} = M_MARK;
	return;
}

=item exclude(App::PFM::File $file [, char $to_mark ] )

Removes a file's mark, or replaces it with I<to_mark>. Updates the
internal (marked) counters.

=cut

sub exclude {
	my ($self, $entry, $to_mark) = @_;
	my $prevmark = $entry->{mark};
	$self->register_exclude($entry) if ($entry->{mark} eq M_MARK);
	$entry->{mark} = $to_mark || ' ';
	return $prevmark;
}

=item register_include(App::PFM::File $file)

Adds a file to the counters of marked files.

=cut

sub register_include {
	my ($self, $entry) = @_;
	$self->{_marked_nr_of}{$entry->{type}}++;
	$entry->{type} =~ /-/ and $self->{_marked_nr_of}{bytes} += $entry->{size};
	$self->{_screen}->set_deferred_refresh(R_DISKINFO);
	return;
}

=item register_exclude(App::PFM::File $file)

Removes a file from the counters of marked files.

=cut

sub register_exclude {
	my ($self, $entry) = @_;
	$self->{_marked_nr_of}{$entry->{type}}--;
	$entry->{type} =~ /-/ and $self->{_marked_nr_of}{bytes} -= $entry->{size};
	$self->{_screen}->set_deferred_refresh(R_DISKINFO);
	return;
}

=item ls()

Used for debugging.

=cut

sub ls {
	my ($self) = @_;
	my $listing = $self->{_screen}->listing;
	foreach my $file (@{$self->{_dircontents}}) {
		print $listing->fileline($file), "\n";
	}
	return;
}

=item set_dirty(int $flag_bits)

Flags that this directory needs to be updated. The B<D_*>
constants (see below) may be used to specify which aspect.

=cut

sub set_dirty {
	my ($self, $bits) = @_;
	$self->{_dirty} |= $bits;
	return;
}

=item unset_dirty(int $flag_bits)

Removes the flag that this directory needs to be updated. The B<D_*>
constants (see below) may be used to specify which aspect.

=cut

sub unset_dirty {
	my ($self, $bits) = @_;
	$self->{_dirty} &= ~$bits;
	return;
}

=item refresh()

Refreshes the aspects of the directory that have been flagged as dirty.

=cut

sub refresh {
	my ($self)  = @_;
	my $smart;
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
		$self->{_screen}->set_deferred_refresh(R_LISTING);
	}
	# now refresh individual elements
	if ($dirty & D_CHDIR) {
		$self->_init_filesystem_info();
	}
	if ($dirty & D_CONTENTS) {
		# the smart flag is only respected if the current directory has changed
		$smart = (
			!($dirty & D_CHDIR) and
			($dirty & D_SMART || $self->{_config}{refresh_always_smart})
		);
		$self->_readcontents($smart);
	}
	if ($dirty & D_SORT) {
		$self->_sortcontents();
	}
	if ($dirty & D_FILTER) {
		$self->_filtercontents();
	}
	return;
}

=item checkrcsapplicable( [ string $path ] )

Checks if any rcs jobs are applicable for this directory,
and starts them.

=cut

sub checkrcsapplicable {
	my ($self, $entry) = @_;
	my $fullclass;
	my $path   = $self->{_path};
	my $screen = $self->{_screen};
	$entry = defined $entry ? $entry : $path;
	my $on_after_job_start = sub {
		# next line needs to provide a '1' argument because
		# $self->{_rcsjob} has not yet been set
		$screen->set_deferred_refresh(R_HEADINGS);
		$screen->frame->rcsrunning(RCS_RUNNING);
		return;
	};
	my $on_after_job_receive_data = sub {
		my $event = shift;
		my $job   = $event->{origin};
		my $count = 0;
		my %nameindexmap =
			map { $_->{name}, $count++ } @{$self->{_showncontents}};
		foreach my $data_line (@{$event->{data}}) {
			my ($flags, $file) = @$data_line;
			my ($topdir, $mapindex, $oldval);
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
		} # endfor $data_line ($event->data)
		# TODO only show if this directory is on-screen (is_main).
		$screen->listing->show();
		$screen->listing->highlight_on();
		return;
	};
	my $on_after_job_finish = sub {
		$self->{_rcsjob} = undef;
		$screen->set_deferred_refresh(R_HEADINGS);
		$screen->frame->rcsrunning(RCS_DONE);
		return;
	};
	# TODO when a directory is swapped out, the jobs should continue
	# Note that this supports only one revision control system per directory.
	foreach my $class (@{$self->RCS}) {
		$fullclass = "App::PFM::Job::$class";
		if ($fullclass->isapplicable($path, $entry)) {
			# If the previous job did not yet finish,
			# kill it and run the command for the entire directory.
			if ($self->stop_any_rcsjob()) {
				$entry = $path;
			}
			$self->{_rcsjob} = $self->{_jobhandler}->start($class, {
				after_job_start			=> $on_after_job_start,
				after_job_receive_data	=> $on_after_job_receive_data,
				after_job_finish		=> $on_after_job_finish,
			}, {
				path     => $entry,
				noignore => $self->{_ignore_mode},
			});
			return;
		}
	}
	return;
}

=item stop_any_rcsjob()

Stop an rcsjob, if it is running.
Returns a boolean indicating if one was running.

=cut

sub stop_any_rcsjob {
	my ($self) = @_;
	if (defined $self->{_rcsjob}) {
		# The after_job_finish handler will reset $self->{_rcsjob}.
		$self->{_jobhandler}->stop($self->{_rcsjob});
		return 1;
	}
	return 0;
}

=item preparercscol( [ App::PFM::File $file ] )

Prepares the 'Version' field in the directory contents by clearing it.
If a I<file> argument is provided, then only process this file;
otherwise, process this entire directory.

=cut

sub preparercscol {
	my ($self, $file) = @_;
	my $layoutfields = $self->{_screen}->listing->LAYOUTFIELDS;
	if (defined $file and $file->{name} ne '.') {
		$file->{$layoutfields->{'v'}} = '-';
		return;
	}
	foreach (0 .. $#{$self->{_showncontents}}) {
		$self->{_showncontents}[$_]{$layoutfields->{'v'}} = '-';
	}
	$self->{_screen}->set_deferred_refresh(R_LISTING);
	return;
}

=item reformat()

Adjusts the visual representation of the directory contents according
to the new layout.

=cut

sub reformat {
	my ($self) = @_;
	# the dircontents may not have been initialized yet
	return unless @{$self->{_dircontents}};
	foreach (@{$self->{_dircontents}}) {
		$_->format();
	}
	return;
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

=item apply(coderef $do_this, App::PFM::Event $event, array @args)

In single file mode: applies the supplied function to the current file,
as passed in I<$event-E<gt>{currentfile}>.
In multiple file mode: applies the supplied function to all marked files
in the current directory.

Special flags can be passed in I<$event-E<gt>{lunchbox}{applyflags}>.

If the apply flags contain 'delete', the directory is processed in
reverse order. This is important when deleting files.

If the apply flags do not contain 'nofeedback', the filename of the file
being processed will be displayed on the second line of the screen.

=cut

sub apply {
	my ($self, $do_this, $event, @args) = @_;
	my $applyflags = $event->{lunchbox}{applyflags};
	my ($loopfile, $deleted_index, $count, %nameindexmap);
	if ($_pfm->state->{multiple_mode}) {
		#$self->{_wasquit} = 0;
		#local $SIG{QUIT} = \&_catch_quit;
		my $screen = $self->{_screen};
		my @range = 0 .. $#{$self->{_showncontents}};
		if ($applyflags =~ /\bdelete\b/o) {
			@range = reverse @range;
			# build nameindexmap on dircontents, not showncontents.
			# this is faster than doing a dirlookup() every iteration
			$count = 0;
			%nameindexmap =
				map { $_->{name}, $count++ } @{$self->{_dircontents}};
		}
		foreach my $i (@range) {
			$loopfile = $self->{_showncontents}[$i];
			if ($loopfile->{mark} eq M_MARK) {
				# don't give feedback in cOmmand or Your
				if ($applyflags !~ /\bnofeedback\b/o) {
					$screen->at($screen->PATHLINE, 0)->clreol()
						->puts($loopfile->{name})->at($screen->PATHLINE+1, 0);
				}
				$loopfile->apply($do_this, $applyflags, @args);
				# see if the file was lost, and we were deleting.
				# we could also test if return value of File->apply eq 'deleted'
				if (!$loopfile->{nlink} and
					$loopfile->{type} ne 'w' and
					$applyflags =~ /\bdelete\b/o)
				{
					$self->unregister($loopfile);
					$deleted_index = $nameindexmap{$loopfile->{name}};
					splice @{$self->{_dircontents}}, $deleted_index, 1;
					$self->set_dirty(D_FILTER);
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
		$_pfm->state->{multiple_mode} = 0 if $self->{_config}{autoexitmultiple};
		$self->checkrcsapplicable() if $self->{_config}{autorcs};
		$screen->set_deferred_refresh(R_LISTING | R_PATHINFO | R_FRAME);
	} else {
		$loopfile = $event->{currentfile};
		$loopfile->apply($do_this, $applyflags, @args);
		$self->checkrcsapplicable($loopfile->{name})
			if $self->{_config}{autorcs};
		# see if the file was lost, and we were deleting.
		# we could also test if return value of File->apply eq 'deleted'
		if (!$loopfile->{nlink} and
			$loopfile->{type} ne 'w' and
			$applyflags =~ /\bdelete\b/o)
		{
			$self->unregister($loopfile);
			$deleted_index = $self->dirlookup(
				$loopfile->{name}, @{$self->{_dircontents}});
			splice @{$self->{_dircontents}}, $deleted_index, 1;
			$self->set_dirty(D_FILTER);
		}
	}
	return;
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

=item D_CHDIR

The current directory was changed, therefore, filesystem usage
information should be updated from disk.

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
