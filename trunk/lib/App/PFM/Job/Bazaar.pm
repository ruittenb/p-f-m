#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Bazaar 0.32
#
# Name:			App::PFM::Job::Bazaar
# Version:		0.32
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-03
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Bazaar

=head1 DESCRIPTION

PFM Job class for Bazaar commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Bazaar;

use base 'App::PFM::Job::RCS';

use strict;
use locale;

##########################################################################
# private subs

=item _init(hashref { $eventname1 => coderef $handler1 [, ...] })

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, @args) = @_;
	$self->{_COMMAND} = 'bzr status -S %s';
	$self->{_base}    = $self->isapplicable(@args);
	$self->SUPER::_init(@args);
}

=item _preprocess(string $data)

Split the status output in a filename- and a status-field.

=cut

# ?   backup.bzr/
#  M  static/media/index.php

sub _preprocess {
	my ($self, $data) = @_;
	my $firstcolsize = 4;
	return [
		substr($data, 0, $firstcolsize),
		$self->{_base} . "/" . substr($data, $firstcolsize)
	];
}

=item _bzrmaxchar(char $a, char $b)

Sorting routine for Bazaar status characters.

=item rcsmax(string $old, string $new)

Determine which status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over

B<C> (conflict) E<gt> B<M>,B<A>,B<D> (modified, added, deleted) E<gt> I<other>

=back

=cut

sub _bzrmaxchar {
	# TODO all very tentative by lack of good examples on the web.
	my ($self, $a, $b) = @_;
	# C conflict
	return 'C' if ($a eq 'C' or $b eq 'C');
	# M modified
	# A added
	# D deleted
	return 'M' if ($a =~ /^[MAD]$/o or $b =~ /^[MAD]$/o);
	# ? unversioned
	return $b  if ($a eq ''  or $a eq '-');
	return $a;
}
 
sub rcsmax {
	my ($self, $old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = $self->_bzrmaxchar(substr($old,0,1), substr($new,0,1));
	substr($res,1,1) = $self->_bzrmaxchar(substr($old,1,1), substr($new,1,1));
	return $res;
}

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item isapplicable(string $path)

Checks if there is a F<.bzr> directory in this or any parent directory,
in which case Bazaar commands would be applicable.

=cut

sub isapplicable {
	my ($self, $path) = @_;
	while ($path and $path =~ m!/!) {
		if (-d "$path/.bzr") {
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
