#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS 0.14
#
# Name:			App::PFM::OS
# Version:		0.14
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-10-23
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS

=head1 DESCRIPTION

Static class that provides platform-independent access to OS commands.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS;

use base 'App::PFM::Abstract';

use App::PFM::OS::Abstract;

use Carp;
use strict;
use locale;

our ($AUTOLOAD);

##########################################################################
# private subs

=item _init( [ App::PFM::Config $config ] )

Initializes new instances. Called from the constructor.
Figures out if we have a specific App::PFM::OS class for this OS,
and stores it internally.

=cut

sub _init {
	my ($self, $config) = @_;
	my $osname = ucfirst lc($^O);
	my $class  = "App::PFM::OS::$osname";
	$self->{_os} = eval "
		require $class;
		return $class->new(\$config);
	";
	if ($@) {
		$self->{_os} = new App::PFM::OS::Abstract($config);
	}
}

##########################################################################
# constructor, getters and setters

=item AUTOLOAD( [ args... ] )

Loads the corresponding method in the OS-specific class.

=cut

sub AUTOLOAD {
	my ($self, @args) = @_;
	my $command = $AUTOLOAD;
	$command =~ s/.*:://;
	return if $command eq 'DESTROY';
	return $self->{_os}->$command(@args);
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
