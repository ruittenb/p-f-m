#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::OS::Darwin 0.03
#
# Name:			App::PFM::OS::Darwin
# Version:		0.03
# Author:		Rene Uittenbogaard
# Created:		2010-08-20
# Date:			2017-09-27
#

##########################################################################

=pod

=head1 NAME

App::PFM::OS::Darwin

=head1 DESCRIPTION

PFM OS class for access to Darwin-specific OS commands.
This class extends App::PFM::OS::Macosx.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::OS::Darwin;

use base 'App::PFM::OS::Macosx';

use strict;
use locale;

#use constant MINORBITS => 2 ** n;

##########################################################################
# private subs

##########################################################################
# constructor, getters and setters

##########################################################################
# public subs

=item hasacl(string $path)

Returns a boolean value indicating if the current file has an acl.

  $ ls -lda /Network /Library
  drwxrwxr-x+   60 root  admin   2040 Apr 10 09:58 Library/
  drwxr-xr-x@    2 root  wheel     68 Jul 30  2016 Network/

  $ ls -lde /Library
  drwxrwxr-x+ 60 root  admin  2040 Apr 10 09:58 /Library/
   0: group:everyone deny delete

  $ ls -lde /Network
  drwxr-xr-x@ 2 root  wheel  68 Jul 30  2016 /Network/

=cut

sub hasacl {
	my ($self, $file) = @_;
	# too slow. needs work.
	# return 0;
	my @res = $self->backtick(qw{ls -lda}, $file);
	return substr($res[0], 10, 1) eq '+';
	my @res = $self->backtick(qw{ls -lde}, $file);
	return @res > 1;
}


##########################################################################

=back

=head1 SEE ALSO

pfm(1), App::PFM::OS(3pm), App::PFM::OS::Abstract(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
