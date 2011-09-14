#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Mercurial 0.06
#
# Name:			App::PFM::Job::Mercurial
# Version:		0.06
# Author:		Rene Uittenbogaard
# Created:		2011-03-07
# Date:			2011-03-07
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Mercurial

=head1 DESCRIPTION

PFM Job class for Mercurial commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Mercurial;

use base 'App::PFM::Job::RCS';

use strict;
use locale;

##########################################################################
# private subs

=item _init(hashref { $eventname1 => coderef $handler1 [, ...] },
hashref { path => string $path, noignore => bool $noignore })

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $handlers, $options) = @_;
	$self->{_COMMAND} = $options->{noignore}
		? 'hg status -m -a -r -d -C -u -i %s'
		: 'hg status -m -a -r -d -C -u %s';
	$self->SUPER::_init($handlers, $options);
	return;
}

=item _preprocess(string $data)

Split the status output in a filename- and a status-field.

=cut

# M  modified
# A  added
# R  removed
# C  clean
# ?  not tracked by hg
# !  missing (deleted by non-hg command, but still tracked)
# I  ignored
#    origin of the previous file listed as A (added)

sub _preprocess {
	my ($self, $data) = @_;
	return [ substr($data, 0, 1), substr($data, 2) ];
}

=item _hgmaxchar(char $a, char $b)

Sorting routine for mercurial status characters.

=item rcsmax(string $old, string $new)

Determines which mercurial status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over 2

B<M>,B<A>,B<R> (modified, added, removed) E<gt> I<other>

=back

=cut

sub _hgmaxchar {
	my ($self, $a, $b) = @_;
	# M modified
	# A added
	# R removed
	return 'M' if ($a =~ /^[MAR]$/o or $b =~ /^[MAR]$/o);
	# I ignored
	# C clean
	# ? unversioned
	# ! missing
	return $b  if ($a eq ''  or $a eq '-');
	return $a;
}

sub rcsmax {
	my ($self, $old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = $self->_hgmaxchar(substr($old,0,1), substr($new,0,1));
	return $res;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item isapplicable(string $path)

Checks if there is a F<.hg> directory in this or any parent directory,
in which case Mercurial commands would be applicable.

=cut

sub isapplicable {
	my ($self, $path) = @_;
	if ($path and $path =~ m!/.hg(?:$|/)!) {
		return 0;
	}
	while ($path and $path =~ m!/!) {
		if (-d "$path/.hg") {
			return $path;
		}
		$path =~ s{/[^/]*$}{};
	}
	return 0;
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
