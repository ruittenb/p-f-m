#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::Job::Cvs 0.31
#
# Name:			App::PFM::Job::Cvs
# Version:		0.31
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-08-24
#

##########################################################################

=pod

=head1 NAME

App::PFM::Job::Cvs

=head1 DESCRIPTION

PFM Job class for CVS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::Job::Cvs;

use base 'App::PFM::Job::RCS';

use App::PFM::Util qw(dirname basename);

use strict;

##########################################################################
# private subs

=item _init(hashref { $event1 => coderef $handler1 [, ...] })

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, @args) = @_;
	# add -l for local (no subdirs)
	$self->{_COMMAND} = 'cd %s; cvs -n -q update %s';
	$self->SUPER::_init(@args);
}

=item _preprocess(string $data)

Split the status output in a filename- and a status-field.

=cut

# RCS file: /vol/cvs/kavnet/kavnetserver.c,v
# retrieving revision 1.11
# retrieving revision 1.13
# Merging differences between 1.11 and 1.13 into kavnetserver.c
# M kavnetserver.c
# M libkavnetclient.h
# M perl/test.pl
# U kavnetserver.c
# ? md5.h
# /^([PMCU\?]) (\S.)/

# ? unversioned
# U updated on server
# P patch (like U, but sends only a diff/patch instead of the entire file).
# M modified
# C conflict

sub _preprocess {
	my ($self, $data) = @_;
	return undef if ($data !~ /^([PMCU\?]) (\S+)/o);
	return [ $1, $2 ];
}

=item _cvsmaxchar(char $a, char $b)

Sorting routine for CVS status characters.

=item rcsmax(string $old, string $new)

Determine which status character should be displayed on
a directory that holds files with different status characters.
For this purpose, a relative priority is defined:

=over

B<C> (conflict) E<gt> B<M> (modified) E<gt> B<U>,B<P> (updated) E<gt> I<other>

=back

=cut

sub _cvsmaxchar {
	my ($self, $a, $b) = @_;
	# C conflict
	return 'C' if ($a eq 'C' or $b eq 'C');
	# M modified
	return 'M' if ($a eq 'M' or $b eq 'M');
	# U updated on server
	# P patch (like U, but sends only a diff/patch instead of the entire file).
	return 'U' if ($a eq 'U' or $b eq 'U' or $a eq 'P' or $b eq 'P');
	# ? unversioned
	return $b  if ($a eq ''  or $a eq '-');
	return $a;
}

sub rcsmax {
	my ($self, $old, $new) = @_;
	my $res = $old;
	substr($res,0,1) = $self->_cvsmaxchar(substr($old,0,1), substr($new,0,1));
	return $res;
}

##########################################################################
# constructor, getters and setters

=item command()

Getter for the command.

=cut

sub command {
	my ($self) = @_;
	my ($dirname, $basename);
	if (-d $self->{_path}) {
		$dirname  = $self->{_path} . "/";
		$basename = '.';
	} else {
		$dirname  = dirname( $self->{_path});
		$basename = basename($self->{_path});
	}
	my $res = sprintf($self->{_COMMAND}, quotemeta $dirname, quotemeta $basename);
	return $res;
}

##########################################################################
# public subs

=item isapplicable(string $path)

Checks if there is a F<CVS> directory, in which case CVS commands
would be applicable.

=cut

sub isapplicable {
	my ($self, $path) = @_;
	return -d "$path/CVS";
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::JobHandler(3pm), App::PFM::Job::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
