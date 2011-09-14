#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS 0.01
#
# Name:			App::PFM::OS
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-21
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
use App::PFM::OS::Aix;
use App::PFM::OS::Darwin;
use App::PFM::OS::Dec_osf;
use App::PFM::OS::Freebsd;
use App::PFM::OS::Hpux;
use App::PFM::OS::Irix;
use App::PFM::OS::Linux;
use App::PFM::OS::Macosx;
use App::PFM::OS::Sco;
use App::PFM::OS::Solaris;
use App::PFM::OS::Sunos;
use App::PFM::OS::Tru64;

use Carp;
use strict;

our ($AUTOLOAD);

##########################################################################
# private subs

=item _init( [ App::PFM::Application $pfm ] )

Initializes new instances. Called from the constructor.
Figures out if we have a specific App::PFM::OS class for this OS,
and stores it internally.

=cut

sub _init {
	my ($self, $pfm) = @_;
	my $osname	= ucfirst lc($^O);
	my $class	= "App::PFM::OS::$osname";
	eval {
		$self->{_os} = $class->new($pfm);
	};
	if ($@) {
		$self->{_os} = new App::PFM::OS::Abstract($pfm);
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
