#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS 0.01
#
# Name:			App::PFM::OS
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2010-08-20
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
#use App::PFM::OS::Linux;
use Carp;

use strict;

our $_os;

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.
Figures out if we have a specific App::PFM::OS class for this OS.

=cut

sub _init {
	my ($self) = @_;
	my $osname = ucfirst lc($^O);
	my $class  = "App::PFM::OS::$osname";
	eval {
		$App::PFM::OS::_os = $class->new();
	};
	if ($@) {
		$_os = App::PFM::OS::Abstract->new();
	}
}

##########################################################################
# constructor, getters and setters

=item AUTOLOAD()

Loads the corresponding method in the OS-specific class.

=cut

sub AUTOLOAD {
	my ($command, @args) = @_;
	return $_os->$command(@args);
}

##########################################################################
# public subs

##########################################################################

=back

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
