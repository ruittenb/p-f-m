#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Directory 0.01
#
# Name:			PFM::Directory.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-01
#

##########################################################################

=pod

=head1 NAME

PFM::Directory

=head1 DESCRIPTION

PFM Directory class, containing the directory contents and the
actions that can be performed on them.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Directory;

use base 'PFM::Abstract';

use PFM::Util;

my ($_pfm, $_path,
	@_dircontents, @_showncontents, %_selected_nr_of, %_total_nr_of);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $path)	= shift;
	$_pfm					= $pfm;
	$_path					= $path;
}

=item _by_sort_mode()

Sorts two directory entries according to the selected sort mode.

=cut

sub _by_sort_mode {
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
#		/v/ and return		$a->{svn}   <=>		$b->{svn},  last SWITCH;
#		/V/ and return		$b->{svn}   <=>		$a->{svn},  last SWITCH;
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

##########################################################################
# constructor, getters and setters

=item path()

Getter/setter for the current directory path.
Setting the current directory in this way is identical to calling
PFM::Directory::chdir(), and will return the success status.

=cut

sub path {
	my ($self, $target) = @_;
	if (defined $target) {
		return $self->chdir($target);
	}
	return $_path;
}

=item dircontents()

Getter/setter for the @_dircontents variable, which contains the
complete array of files in the directory.

=cut

sub dircontents {
	my ($self, @value) = @_;
	@_dircontents = @value if @value;
	return \@_dircontents;
}

=item showncontents()

Getter/setter for the @_showncontents variable, which contains an
array of the files shown on-screen.

=cut

sub showncontents {
	my ($self, @value) = @_;
	@_showncontents = @value if @value;
	return \@_showncontents;
}

=item total_nr_of()

Getter for the hash which keeps track of how many directory entities
of each type there are.

=cut

sub total_nr_of {
	my ($self) = @_;
	return \%_total_nr_of;
}

=item selected_nr_of()

Getter for the hash which keeps track of how many directory entities
of each type have been selected.

=cut

sub selected_nr_of {
	my ($self) = @_;
	return \%_selected_nr_of;
}

##########################################################################
# public subs

sub chdir {
	my ($self, $target) = @_;
	my $result;
	my $screen = $_pfm->screen;
	if ($target eq '') {
		$target = $ENV{HOME};
	} elsif (-d $target and $target !~ m!^/!) {
		$target = "$_path/$target";
	} elsif ($target !~ m!/!) {
		foreach (split /:/, $ENV{CDPATH}) {
			if (-d "$_/$target") {
				$target = "$_/$target";
				$screen->at(0,0)->clreol();
				$screen->display_error("Using $target");
				$screen->at(0,0);
				last;
			}
		}
	}
	#TODO canonicalize_path
	$target = canonicalize_path($target);
	if ($result = chdir $target and $target ne $_path) {
		#TODO define constants for oldcwd
		$_pfm->state(2) = $self;
		$_path = $target;
		$chdirautocmd = $_pfm->config->chdirautocmd;
		system("$chdirautocmd") if length($chdirautocmd);
		$screen->set_deferred_refresh($screen->R_CHDIR);
	}
	return $result;
}

sub init_dircount {
	%_selected_nr_of = %_total_nr_of =
		( d=>0, '-'=>0, l=>0, c=>0, b=>0, D=>0,
		  p=>0, 's'=>0, n=>0, w=>0, bytes => 0 );
}

#TODO
sub countdircontents {
	$self->init_dircount();
	foreach my $i (0..$#_) {
		$_total_nr_of   {$_[$i]{type}}++;
		$_selected_nr_of{$_[$i]{type}}++ if ($_[$i]{selected} eq '*');
	}
}

# TODO
sub readcontents {
	my (@contents, $entry);
	my @allentries = ();
	my @white_entries = ();
	%usercache = %groupcache = ();
#	draw_headings($swap_mode, $TITLE_DISKINFO, @layoutfieldswithinfo);
	if (opendir CURRENT, '.') { # was $_path
		@allentries = readdir CURRENT;
		closedir CURRENT;
		if ($white_cmd) {
			@white_entries = `$white_cmd $_[0]`;
		}
	} else {
		$scr->at(0,0)->clreol();
		display_error("Cannot read . : $!");
	}
	# next lines also correct for directories with no entries at all
	# (this is sometimes the case on NTFS filesystems: why?)
	if ($#allentries < 0) {
		@allentries = ('.', '..');
	}
#	local $SIG{INT} = sub { return @contents };
	if ($#allentries > $SLOWENTRIES) {
		# don't use display_error here because that would just cost more time
		$scr->at(0,0)->clreol()->putcolored($framecolors{$color_mode}{message}, 'Please Wait');
	}
	foreach $entry (@allentries) {
		# have the mark cleared on first stat with ' '
		push @contents, stat_entry($entry, ' ');
	}
	foreach $entry (@white_entries) {
		$entry = stat_entry($entry, ' ');
		$entry->{type} = 'w';
		substr($entry->{mode}, 0, 1) = 'w';
		push @contents, $entry;
	}
	draw_menu();
	handlemorercsopen() if $autorcs;
	draw_headings($swap_mode, $TITLE_DISKINFO, @layoutfieldswithinfo);
	return @contents;
}

=item sortcontents()

Sorts the directory's contents according to the selected sort mode.

=cut

sub sortcontents {
	# TODO sorteer uitdaging
	@_dircontents  = sort { $self->_by_sort_mode } @_dircontents;
}

=item filtercontents()

Filters the directory contents according to the filter modes
(displays or hides dotfiles and whiteouts).

=cut

sub filtercontents {
	@_showncontents = grep {
		$_pfm->state->{dot_mode}   || $_->{name} =~ /^(\.\.?|[^\.].*)$/ and
		$_pfm->state->{white_mode} || $_->{type} ne 'w'
	} @_dircontents;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
