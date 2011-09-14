/*
 *#########################################################################
 *
 * Name:         listwhite
 * Version:      0.09
 * Author:       Rene Uittenbogaard
 * Date:         2003-05-15
 * Last change:  2010-05-30
 * Usage:        listwhite [ <directories> .. ]
 * Description:  List the names of all whiteout entries in the specified
 *               directories
 *
 */

#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <fts.h>

#define BUFSIZE 1024

static const char id[] = "@(#) listwhite 20030515 v0.09";

int main(int argc, char **argv)
{
	char **pathnames;
	char *errormsg;
	FTS *tree_stream;
	FTSENT *tree_entry;
	char *dummy;

	if (argc > 1)
	{
		pathnames = argv;
		pathnames++;
	}
	else
	{
		pathnames    = (char **)malloc(2 * sizeof(char *));
		pathnames[0] = (char *) malloc(BUFSIZE);
		dummy = getcwd(pathnames[0], BUFSIZE);
		pathnames[1] = NULL;
	}
	if (!(tree_stream =
		fts_open(pathnames, FTS_PHYSICAL | FTS_WHITEOUT, NULL)))
	{
		errormsg = (char *)malloc(BUFSIZE);
		sprintf(errormsg, "cannot fts_open(\"%s\", ...)", pathnames[0]);
		perror(errormsg);
		return 1;
	}
	while (tree_entry = fts_read(tree_stream))
	{
		if (tree_entry->fts_info != FTS_NS)
		{
			// stat(2) info available
			if (tree_entry->fts_info == FTS_W)
			{
				// found whiteout
				printf("%s\n", tree_entry->fts_name);
			}
			else if ((tree_entry->fts_info == FTS_D) &&
					(tree_entry->fts_level == 1))
			{
				// skip subdirectories
				fts_set(tree_stream, tree_entry, FTS_SKIP);
			}
		}
	}
	fts_close(tree_stream);
	return 0;
}

/*

=pod

=for section 1

=head1 NAME

listwhite - list whiteout entries

=head1 SYNOPSIS

B<listwhite >[ I<directories...> ]

=head1 DESCRIPTION

C<listwhite> lists the names of all the whiteout entries in the specified
directories.

=head1 OPTIONS

None.

=head1 BUGS

None known.

=head1 VERSION

This manual pertains to C<listwhite> version 0.09.

=head1 SEE ALSO

ls(1), stat(2).

=head1 AUTHOR

Written by RenE<eacute> Uittenbogaard (ruittenb@users.sourceforge.net).

=head1 COPYRIGHT

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

=cut

*/
