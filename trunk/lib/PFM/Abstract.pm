#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Abstract 2010-03-27 v0.01
#
# Name:			PFM::Abstract.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Description:	The PFM Abstract class that defines shared functions.
#

##########################################################################
# declarations

package PFM::Abstract;

use Carp;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

=item new()

Constructor for all classes based on PFM::Abstract.

=cut

sub new {
	my $type = shift;
	if ($type eq __PACKAGE__) {
		croak(__PACKAGE__, ' should not be instantiated');
	}
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init(@_);
	return $self;
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
