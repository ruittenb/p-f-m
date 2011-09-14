/*
 *#########################################################################
 *
 * Name:	hasacl
 * Version:	0.07
 * Author:	Rene Uittenbogaard
 * Date:	2011-09-05
 * Last change:	2011-09-05
 * Usage:	hasacl [ -v ] [ <file> ]
 * Description:	Tells if a (non-trivial) ACL is present for
 * 		the indicated file.
 *
 */

#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/acl.h>

#define BUFSIZE 1024
#define ARGV0   "hasacl"

#define ERR_USAGE	100
#define ERR_ACLGET	101

static const char id[] = "@(#) hasacl 20110905 v0.07";

void usage()
{
	fprintf(stderr, "Usage: " ARGV0 " [ -v ] [ <file> ]\n");
}

int main(int argc, char **argv)
{
	// declarations

	extern char *optarg;
	extern int optind, opterr, optopt;
	extern int errno;

	const char *optstring = "v";
	int option;
	int opt_v = 0;

	char        *current_path;
	acl_t        current_acl;
	mode_t      *current_mode;
	int success, equal;

	// code

	while ((option = getopt(argc, argv, optstring)) > 0)
	{
		switch (option) {
			case 'v': opt_v = 1; break;
			default : usage(); exit(ERR_USAGE);
		}
	}

        if (argc < optind) {
		current_path = ".";
        } else {
		current_path = argv[optind];
	}
	current_acl  = acl_get_file(current_path, ACL_TYPE_ACCESS);
	if (current_acl == (acl_t)NULL) {
		exit(ERR_ACLGET);
	}
	equal = acl_equiv_mode(current_acl, current_mode);
	if (opt_v) {
		fprintf(stdout, "%d\n", equal);
	}
	exit(!equal);
}

/*

=pod

=for section 8

=head1 NAME

hasacl - tell whether a file has a (non-trivial) ACL

=head1 SYNOPSIS

B<hasacl >[ -v ] [ I<file> ]

=head1 DESCRIPTION

C<hasacl> tells if a (non-trivial) ACL is present for the indicated file.
A non-trivial ACL is an ACL that cannot be expressed with just one owner,
one group and the standard mode bits.

=head1 OPTIONS

=over 4

=item -v

Verbose mode. In addition to setting the exit code (0 for true,
1 for false), C<hasacl> will print 0 (false) or 1 (true) on stdout.
If not present, only the exit code will be set.

=back

If no I<file> is provided, the current directory is checked instead.

=head1 RETURN VALUE

In case of success, returns 0 if the file has a (non-trivial) ACL,
or 1 otherwise.

In case of failure, returns 100 if there was a commandline option
problem, or 101 if there was an error fetching the ACL for the file.

=head1 BUGS

This program is currently Linux-specific.
Ideally, this should be using the coreutils hasacl.h.

=head1 VERSION

This manual pertains to C<hasacl> version 0.07.

=head1 SEE ALSO

acl(5), acl_get_file(3), acl_equiv_mode(3).

=head1 AUTHOR

Written by RenE<eacute> Uittenbogaard (ruittenb@users.sourceforge.net).

=head1 COPYRIGHT

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

=cut

*/
