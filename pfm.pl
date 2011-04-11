#!/usr/bin/env perl
#
##########################################################################
#
# Name:			pfm
# Version:		2.03.6
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-05-04
# Usage:		pfm [ <directory> ] [ -s, --swap <directory> ]
#				    [ -l, --layout <number> ]
#				pfm { -v, --version | -h, --help }
# Requires:		PFM::Application
#				Term::ReadLine (preferably Term::ReadLine::Gnu)
#				Term::ScreenColor
#				Getopt::Long
#				LWP::Simple
# Description:	Personal File Manager for Unix/Linux
#				Based on PFM.COM for DOS.
#

##########################################################################
# version

# for MakeMaker
our $VERSION = '2.03.6';

# macros for *roff
our $ROFFVERSION = <<'=cut';

=pod

=for roff
.ds Yr 2010
.ds Vw @(#) pfm.pl 2.03.6
.de Vp
This manual pertains to \f(CWpfm\fP version \\$3.
..
.hy 0 \" hyphenation off

=cut

##########################################################################
# declarations

use lib '/home/ruitten/Desktop/projects/pfm/z_working/pfm2/lib';
use strict;

use App::PFM::Application;

my $pfm;

END {
	# in case something goes wrong:
	# alternate screen off, 'cooked' mode
	print "\e[?47l";
	system qw(stty -raw echo);
}

##########################################################################
# main

$pfm = new App::PFM::Application();
$pfm->run();

exit 0;

__END__

##########################################################################
# pod documentation

=pod

=head1 NAME

C<pfm> - Personal File Manager for Linux/Unix

=head1 SYNOPSIS

C<pfm [ -l, --layout >I<number>C< ]>
C< [ >I<directory>C< ] [ -s, --swap >I<directory>C< ]>

C<pfm { -v, --version | -h, --help }>

=head1 DESCRIPTION

C<pfm> is a terminal-based file manager, based on PFMS<.>COM for MS-DOS.

All C<pfm> commands are accessible through one or two keystrokes, and a few
are accessible with the mouse. Most command keys are case-insensitive. C<pfm>
can operate in single-file mode or multiple-file mode. In single-file mode,
the command corresponding to the keystroke will be performed on the current
(highlighted) file only. In multiple-file mode, the command will apply to
a selection of files.

Note that throughout this manual page, I<file> can mean any type of file,
not just plain regular files. These will be referred to as I<regular files>.

=head1 OPTIONS

Most of C<pfm>'s configuration is read from a config file. The default
location for this file is F<$HOME/.pfm/.pfmrc>, but an alternative location
may be specified using the environment variable C<PFMRC>. If there is no
config file present at startup, one will be created. The file contains
many comments on the available options, and is therefore supposed to be
self-explanatory. C<pfm> will issue a warning if the config file version
is older than the version of C<pfm> you are running. In this case, please
let C<pfm> create a new default config file and compare the changes with
your own settings, so that you do not miss out on any new config options
or format changes. See also the B<C>onfig command under MORE COMMANDS
below, and DIAGNOSIS.

There are two commandline options that specify starting directories.
The C<CDPATH> environment variable is taken into account when C<pfm>
tries to find these directories.

=over

=item I<directory>

The directory that C<pfm> should initially use as its main directory. If
unspecified, the current directory is used.

=item -h, --help

Print usage information, then exit.

=item -l, --layout I<number>

Start C<pfm> using the specified column layout (as defined in the F<.pfmrc>).

=item -s, --swap I<directory>

The directory that C<pfm> should initially use as swap directory. (See
also the B<F7> command below).

There would be no point in setting the swap directory and subsequently
returning to the main directory if 'persistentswap' is turned off in your
config file. Therefore, C<pfm> will swap back to the main directory I<only>
if 'persistentswap' is turned on.

=item -v, --version

Print current version, then exit.

=back

=head1 NAVIGATION

Navigation through directories is essentially done using the arrow keys
and the vi(1) cursor keys (B<hjkl>). The following additional navigation
keys are available:

Movement inside a directory:

=begin html

<table border="0" cellspacing="4" align="center" width="80%">
<tr><td colspan="2"><hr /></td></tr>
<tr>
	<td width="30%"><i>up arrow</i>, <i>down arrow</i></td>
	<td>move the cursor by one line</td>
</tr>
<tr>
	<td><b>k</b>, <b>j</b></td>
	<td>move the cursor by one line</td>
</tr>
<tr>
	<td><b>-</b>, <b>+</b></td>
	<td>move the cursor by ten lines</td>
</tr>
<tr>
	<td><b>CTRL-E</b>, <b>CTRL-Y</b></td>
	<td>scroll the screen by one line</td>
</tr>
<tr>
	<td><b>CTRL-U</b>, <b>CTRL-D</b></td>
	<td>move the cursor by half a page</td>
</tr>
<tr>
	<td><b>CTRL-B</b>, <b>CTRL-F</b></td>
	<td>move the cursor by a full page</td>
</tr>
<tr>
	<td><b>PgUp</b>, <b>PgDn</b></td>
	<td>move the cursor by a full page</td>
</tr>
<tr>
	<td><b>HOME</b>, <b>END</b></td>
	<td>move the cursor to the top or bottom line</td>
</tr>
<tr>
	<td><b>SPACE</b></td>
	<td>mark the current file, then move the cursor one line down</td>
</tr>
</tr>
<tr><td colspan="2"><hr /></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lw(20n) | lw(41n).
_
\fIup arrow\fP, \fIdown arrow\fP	move the cursor by one line
\fBk\fP, \fBj\fP	move the cursor by one line
\fB-\fP, \fB+\fP	move the cursor by ten lines
\fBCTRL-E\fP, \fBCTRL-Y\fP	scroll the screen by one line
\fBCTRL-U\fP, \fBCTRL-D\fP	move the cursor by half a page
\fBCTRL-B\fP, \fBCTRL-F\fP	move the cursor by a full page
\fBPgUp\fP, \fBPgDn\fP	move the cursor by a full page
\fBHOME\fP, \fBEND\fP	move the cursor to the top or bottom line
.\"_	_
\fBSPACE\fP	T{
mark the current file,
then move the cursor one line down
T}
_
.TE
.in

=end roff

Movement between directories:

=begin html

<table border="0" cellspacing="4" align="center" width="80%">
<tr><td colspan="2"><hr /></td></tr>
<tr>
	<td width="30%"><i>right arrow</i>, <b>l</b></td>
	<td><i>chdir()</i> to a subdirectory</td>
</tr>
<tr>
	<td><i>left arrow</i>, <b>h</b></td>
	<td><i>chdir()</i> to the parent directory</td>
</tr>
<tr>
	<td><b>ENTER</b></td>
	<td><i>chdir()</i> to a subdirectory</td>
</tr>
<tr>
	<td><b>ESC</b>, <b>BS</b></td>
	<td><i>chdir()</i> to the parent directory</td>
</tr>
<tr><td colspan="2"><hr /></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lw(20n) | lw(41n).
_
\fIright arrow\fP, \fBl\fP	\fIchdir()\fP to a subdirectory
\fIleft arrow\fP, \fBh\fP	\fIchdir()\fP to the parent directory
\fBENTER\fP	\fIchdir()\fP to a subdirectory
\fBESC\fP, \fBBS\fP	\fIchdir()\fP to the parent directory
_
.TE
.in

=end roff

If the option 'chdirautocmd' has been specified in the F<.pfmrc> file,
pfm will execute that command after every chdir().

Note 1: the B<l> and B<ENTER> keys function differently when the cursor
is on a non-directory file (see below under B<L>ink and LAUNCHING FILES
respectively).

Note 2: see below under BUGS on the functioning of B<ESC>.

=head1 COMMANDS

=over

=item B<Attrib>

Changes the mode of the file if you are the owner. The mode may be specified
either symbolically or numerically, see chmod(1) for more details.

Note 1: the mode on a symbolic link cannot be set. See chmod(1) for more
details.

Note 2: the name B<Attrib> for this command is a reminiscence of the DOS
version.

=item B<Copy>

Copy current file. You will be prompted for the destination filename.
Directories will be copied recursively with all underlying files.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a destination. Instead, the destination name must be a
directory or a name containing a B<=1>, B<=2> or B<=7> escape (see below
under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten unless the action is confirmed by the user.

=item B<Delete>

Delete a file or directory. You must confirm this command with B<Y>
to actually delete the file. If the current file is a directory which
contains files, and you want to delete it recursively, you must respond with
B<A>ffirmative to the additional prompt. Lost files (files on the screen
but not actually present on disk) can be deleted from the screen listing
without confirmation. Whiteouts cannot be deleted; use unB<W>hiteout for
this purpose.

=item B<Edit>

Edit a file with your external editor. You can specify an editor with the
environment variable VISUAL or EDITOR or with the 'editor' option
in the F<.pfmrc> file. Otherwise vi(1) is used.

=item B<Find>

If the current sort mode is by filename, you are prompted for a (partial)
filename. While you type, the cursor is positioned on the best match. 
Type ENTER to end typing.

If the current sort mode is not by filename, then you are prompted for a
filename. The cursor is then positioned on that file.

=item B<tarGet>

Allows you to change the target that a symbolic link points to. You must
have permission to remove the current symbolic link.

=item B<Include>

Allows you to mark a group of files which meet a certain criterion:

=over

=item B<A>fter / B<B>efore

files newer/older than a specified date and time

=item B<E>very file

all files, including dotfiles, except for the B<.> and B<..> entries

=item B<F>iles only

regular files of which the filenames match a specified regular expression
(not a glob pattern!)

=item B<O>ldmarks

files which were previously marked and are now denoted with
an I<oldmark> (B<.>).

=item B<U>ser

files owned by the current user

=back

Oldmarks may be used to perform more than one command on a group of files.

=item B<Link>

Prompts to create either:

=over

=item an B<A>bsolute symlink

This will create a symlink containing an absolute path to the target,
irrespective of whether you enter a relative or an absolute symlink name.

Example: when the cursor is on the file F</home/rene/incoming/.plan>,
and you request an absolute symlink to be made with either the name
F<../.plan> or F</home/rene/.plan>, the actual symlink will become:

    /home/rene/.plan -> /home/rene/incoming/.plan

=item a B<H>ard link

This will create an additional hard link to the current file with the
specified name, which must be on the same filesystem.

=item a B<R>elative symlink

This will create a symlink containing a relative path to the target,
irrespective of whether you enter a relative or an absolute symlink name.

Example: when the cursor is on the file F</home/rene/incoming/.plan>,
and you request a relative symlink to be made with either the name
F<../.plan> or F</home/rene/.plan>, the actual symlink will become:

    /home/rene/.plan -> incoming/.plan

=back

If a directory is specified, C<pfm> will follow the behavior of ln(1),
which is to create the new link inside that directory.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a new name. Instead, the new name must be a directory or a
name containing a B<=1>, B<=2> or B<=7> escape (see below under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten.

Note that if the current file is a directory, the B<l> key, being one of
the vi(1) cursor keys, will chdir() you into the directory. The capital B<L>
command will I<always> try to make a link.

=item B<More>

Presents you with a choice of operations not related to the current
files. Use this to configure C<pfm>, edit a new file, make a new directory,
show a different directory, or write the history files to disk. See below
under MORE COMMANDS. Pressing B<ESC> will take you back to the main menu.

=item B<Name>

Shows the complete long filename. For a symbolic link, this command
will also show the target of the symbolic link. This is useful in case
the terminal is not wide enough to display the entire name, or if the
name contains non-printable characters. Non-ASCII characters and control
characters will be displayed as their octal or hexadecimal equivalents like
the examples in the following table. Spaces will be converted as well, if
the 'translatespace' option is turned on in the F<.pfmrc> file.  When the
name is shown in its converted form, pressing B<*> will change the radix.
The 'defaultradix' option specifies the initial radix that will be used.

Examples:

=begin html

<table border="0" cellspacing="4" align="center" width="50%">
<tr><td colspan="3"><hr /></td></tr>
<tr>
	<td rowspan="3">character</td>
	<td colspan="2">representation in radix</td>
</tr>
<tr>
	<td colspan="2"><hr /></td>
</tr>
<tr>
	<td>octal</td>
	<td>hexadecimal</td>
</tr>
<tr><td colspan="3"><hr /></td></tr>
<tr>
	<td>CTRL-A</td>
	<td>\001</td>
	<td>\0x01</td>
</tr>
<tr>
	<td>space</td>
	<td>\040</td>
	<td>\0x20</td>
</tr>
<tr>
	<td>c cedilla (<b>&ccedil;</b>)</td>
	<td>\347</td>
	<td>\0xe7</td>
</tr>
<tr>
	<td>backslash (<b>\</b>)</td>
	<td>\\</td>
	<td>\\</td>
</tr>
<tr><td colspan=3><hr /></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
l  | c  s
l6 | l8 l.
_
character	representation in radix
_
\^	octal	hexadecimal\0
_
CTRL-A	\\001	\\0x01
space	\\040	\\0x20
c cedilla (\fB\(,c\fP)	\\347	\\0xe7
backslash (\fB\\\fP)	\\\\	\\\\\0
_
.TE
.in

=end roff

=item B<cOmmand>

Allows execution of a shell command. After the command completes, C<pfm>
will resume.

On the commandline, you may use several special abbreviations, which will
be replaced by C<pfm> with the current filename, directoryname etc. (see
below). These abbreviations start with an escape character. This escape
character is defined with the option 'escapechar' in your F<.pfmrc> file. The
default is B<=>. Previous versions of C<pfm> used B<\>, but this was deemed
too confusing because backslashes are parsed by the shell as well. This
manual page (and the default config file) will assume you are using B<=> as
'escapechar'.

The following abbreviations are available:

=over

=item B<=1>

the current filename without extension (see below)

=item B<=2>

the current filename, complete

=item B<=3>

the full current directory path

=item B<=4>

the mountpoint of the current filesystem

=item B<=5>

the full swap directory path (see B<F7> command)

=item B<=6>

the basename of the current directory

=item B<=7>

the extension of the current filename (see below)

=item B<=8>

a space-separated list of all selected filenames

=item B<==>

a single literal B<=>

=item B<=e>

the editor specified with the 'editor' option in the config file

=item B<=p>

the pager specified with the 'pager' option in the config file

=item B<=v>

the image viewer specified with the 'viewer' option in the config file

=back

The I<extension> of the filename is defined as follows:

If the filename does not contain a period at all, then the file has no
extension (B<=7> is empty) and its whole name is regarded as B<=1>.

If the filename does contain a period, the extension B<=7> is defined
as the final part of the filename, starting at the last period in the
name. The filename B<=1> is the part before the period.

In all cases, the concatenation of B<=1> and B<=7> is equal to B<=2>.

Examples:

=begin html

<table border="0" cellspacing="4" align="center" width="50%">
<tr><td colspan="3"><hr /></td></tr>
<tr>
	<td><b>=2</b></td>
	<td><b>=1</b></td>
	<td><b>=7</b></td>
</tr>
<tr><td colspan="3"><hr /></td></tr>
<tr>
	<td>track01.wav</td>
	<td>track01</td>
	<td>.wav</td>
</tr>
<tr>
	<td>garden.jpg</td>
	<td>garden</td>
	<td>.jpg</td>
</tr>
<tr>
	<td>end.</td>
	<td>end</td>
	<td>.</td>
</tr>
<tr>
	<td>somename</td>
	<td>somename</td>
	<td><i>empty</i></td>
</tr>
<tr>
	<td>.profile</td>
	<td><i>empty</i></td>
	<td>.profile</td>
</tr>
<tr>
	<td>.profile.old</td>
	<td>.profile</td>
	<td>.old</td>
</tr>
<tr><td colspan="3"><hr /></td></tr>
</table>

=end html

=begin roff

.in +4n
.TS
lb | lb lb
l  | l  l  .
_
=2	=1	=7
_
track01.wav	track01	.wav
garden.jpg	garden	.jpg
end.	end	.
somename	somename	\fIempty\fP
\.profile	\fIempty\fP	.profile
\.profile.old	.profile	.old
_
.TE
.in -4n

=end roff

See also below under QUOTING RULES.

=item B<Print>

Will prompt for a print command (default C<lpr -P$PRINTER =2>, or C<lpr =2>
if C<PRINTER> is unset) and will run it. No formatting is done. You may
specify a print command with the 'printcmd' option in the F<.pfmrc> file.

=item B<Quit>

Exit C<pfm>. The option 'confirmquit' in the F<.pfmrc> file specifies
whether C<pfm> should ask for confirmation. Note that by pressing a capital
B<Q> (quick quit), you will I<never> be asked for confirmation.

=item B<Rename>

Change the name of the file and/or move it into another directory. You will
be prompted for the new filename. Depending on your Unix implementation,
a pathname on another filesystem may or may not be allowed.

In multiple-file mode, it is not allowed to specify a single non-directory
filename as a new name. Instead, the new name must be a directory or a
name containing a B<=1> or B<=2> escape (see above under cB<O>mmand).

If clobber mode is off (see below under the B<!> command), existing files
will not be overwritten unless the action is confirmed by the user.

=item B<Show>

Displays the contents of the current file or directory on screen.
You can choose which pager to use for file viewing with the environment
variable C<PAGER>, or with the 'pager' option in the F<.pfmrc> file.

=item B<Time>

Change mtime (modification date/time) of the file. The time may be entered
either with or without clarifying interpunction (e.g. 2008-12-04 08:42.12)
as the interpunction will be removed to obtain a format which touch(1)
can use. Enter B<.> to set the mtime to the current date and time.

=item B<Uid>

Change ownership of a file. Note that many Unix variants do not allow normal
(non-C<root>) users to change ownership. Symbolic links will be followed.

=item B<Version>

Updates the current file with RCS status information. C<pfm> will examine
the current directory to figure out which versioning system is used.
See also B<M>ore - B<V>ersion.

=item B<unWhiteout>

(Only on platforms that support whiteout files). Provides the option
to remove the whiteout entry in the top layer of a translucent (tfs),
inheriting (ifs) or union (unionfs) filesystem, thereby restoring access
to the corresponding file in the lower layer.

=item B<eXclude>

Allows you to erase marks on a group of files which meet a certain
criterion. See B<I>nclude for details.

=item B<Your command>

Like cB<O>mmand (see above), except that it uses one-letter commands
(case-sensitive) that have been preconfigured in the F<.pfmrc> file.
B<Y>our commands may use B<=1> up to B<=8> and B<=e>, B<=p> and B<=v>
escapes just as in cB<O>mmand, e.g.

    your[c]:tar cvf - =2 | gzip > =2.tar.gz
    your[t]:tar tvf =2 | =p
    your[o]:svn commit =8

=item B<siZe>

For directories, reports the grand total (in bytes) of the directory
and its contents.

For other file types, reports the total number of bytes in allocated
data blocks. For regular files, this is often more than the reported
file size. For special files and I<fast symbolic links>, the number is
zero, as no data blocks are allocated for these file types.

If the screen layout (selected with B<F9>) contains a 'grand total' column,
that column will be used. Otherwise, the 'filesize' column will temporarily
be (mis)used. A 'grand total' column in the layout will never be filled in
when entering the directory.

Note: since du(1) commands are not portable, C<pfm> guesses how it can
calculate the size according to the Unix variant that it runs on. If C<pfm>
guesses this incorrectly, you might have to specify the C<du> command (or
C<du | awk> combination) applicable for your Unix version in the F<.pfmrc>
file. Examples are provided. Please notify the author if you know any
corrections that should be made.

=back

=head1 MORE COMMANDS

These commands are accessible through the main screen B<M>ore command.

=over

=item B<Bookmark>

This command will push the current directory onto the path history. With
the B<M>ore - B<S>how command, it can be recalled using the up-arrow key.

=item B<Config pfm>

This command will open the F<.pfmrc> config file with your preferred
editor. The file will be re-read by C<pfm> after you exit your editor.
Options that are only modifiable through the config file (like
'columnlayouts') will be reinitialized immediately, options that affect
settings modifiable by key commands (like 'defaultsortmode') will not.

=item B<Edit new file>

You will be prompted for the new filename, then your editor will
be spawned.

=item B<make Fifo>

Prompts for a name, then creates a FIFO file (named pipe) with that
name. See also fifo(4) and mkfifo(1).

=item B<sHell>

Spawns your default login shell. When you exit from it, C<pfm> will resume.

=item B<Make new directory>

Specify a new directory name and C<pfm> will create it for you. Furthermore,
if you don't have any files marked, your current directory will be set to
the newly created directory.

=item B<Show directory>

You will be asked for the directory you want to view. Note that this
command is different from B<F7> because this will not change your current
swap directory status.

=item B<Version>

Updates the current directory with RCS status information.
If you set the 'autorcs' option in your F<.pfmrc>, this will automatically
be done every time C<pfm> shows directory contents.

=item B<Write history>

C<pfm> uses the readline library for keeping track of the Unix commands,
pathnames, regular expressions, modification times, and file modes
entered. The history is read from individual files in F<$HOME/.pfm/>
every time C<pfm> starts. The history is written only when this command
is given, or when C<pfm> exits and the 'autowritehistory' option is set
in F<.pfmrc>.

=back

=head1 MISCELLANEOUS and FUNCTION KEYS

=over

=item B<ENTER>

If the current file is a directory, C<pfm> will chdir() to that directory.
Otherwise, C<pfm> will attempt to I<launch> the file. See LAUNCHING
FILES below.

=item B<DEL>

Identical to the B<D>elete command (see above).

=item B<!>

Toggle clobber mode. This controls whether a file should be overwritten when
its name is reused in B<C>opy, B<L>ink or B<R>ename.

=item B<">

Toggle pathname handling. In B<physical> mode, the current directory path
will always be transformed to its canonical form (the simplest form, with
symbolic names resolved). In B<logical> mode, all symbolic link components
in the current directory path will be preserved.

=item B<%>

Toggle show/hide whiteout files.

=item B<S< *>>

Toggle the radix used by the B<N>ame command.

=item B<.>

Toggle show/hide dot files.

=item B</>

Identical to B<F>ind (see above).

=item B<E<lt>>

Scroll the header and footer, in order to view all available commands.

=item B<=>

Cycle through displaying the username, the hostname, or username@hostname.

=item B<E<gt>>

Scroll the header and footer, in order to view all available commands.

=item B<?>

Display help. Identical to B<F1>.

=item B<@>

Allows the user to enter a perl command to be executed in the context
of C<pfm>. Primarily used for debugging.

=item B<F1>

Display help, version number and license information.

=item B<F2>

chdir() back to the previous directory.

=item B<F3>

Fit the file list into the current window and refresh the display.

=item B<F4>

Change the current colorset. Multiple colorsets may be defined,
see the F<.pfmrc> file itself for details.

=item B<F5>

Current directory will be reread. Use this when the contents of the
directory have changed. This command will erase all marks.

=item B<F6>

Allows you to re-sort the directory listing. You will be presented
a number of sort modes.

=item B<F7>

Alternates the display between two directories. When switching for the first
time, you are prompted for a directory path to show. When you switch back by
pressing B<F7> again, the contents of the alternate directory are displayed
unchanged. Header text changes color when in swap screen. In shell commands,
the directory path from the alternate screen may be referred to as B<=5>.
If the 'persistentswap' option has been set in the config file, then
leaving the swap mode will store the main directory path as swap path again.

=item B<F8>

Toggles the mark (include flag) on an individual file.

=item B<F9>

Toggle the column layout. Layouts are defined in your F<.pfmrc>,
in the 'defaultlayout' and 'columnlayouts' options. See the config
file itself for information on changing the column layout.

Note that a 'grand total' column in the layout will only be filled when
the siB<Z>e command is issued, not when reading the directory contents.

=item B<F10>

Switch between single-file and multiple-file mode.

=item B<F11>

Refresh (using lstat(2)) the displayed file data for the current file.

=item B<F12>

Toggle mouse use. See below under MOUSE COMMANDS.

=back

=head1 LAUNCHING FILES

The B<ENTER> key, when used on a non-directory file, will attempt to launch
the file.

The command used for launching a file is determined by the file type. File
types are identified by a unique name, preferably MIME type names. Launch
commands for every file type may be defined using the config file
'launch[I<filetype>]' options.

Example:

    launch[image/gif]      :=v =2 &
    launch[application/pdf]:acroread =2 &

There are three methods for determining the file type. You may opt to
use one, two, or all three of these methods, thereby using the second and
third method as fallback.

The following methods are available:

=over

=item B<extension>

The filename extension will be translated to a file type using the
'extension[*.I<extension>]' options in the config file.

Example:

    extension[*.gif]:image/gif
    extension[*.pdf]:application/pdf

=item B<magic>

The file(1) command will be run on the current file. Its output will
be translated to a file type using the 'magic[I<regular expression>]'
options in the config file.

Example:

    magic[GIF image data]:image/gif
    magic[PDF document]  :application/pdf

=item B<xbit>

The executable bits in the file permissions will be checked (after
symbolic links have been followed). If the current file is executable,
C<pfm> will attempt to start the file as an executable command.

=back

To select which method or methods (I<extension>, I<magic>, and/or I<xbit>)
should be used for determining the file type, you should specify these
using the 'launchby' option (separated by commas if more than one).

Example:

    launchby:xbit,extension

If the file type cannot be determined, the current file will be displayed
using your pager.

The B<ENTER> key will always behave as if C<pfm> runs in single-file mode.
It will I<not> launch multiple files. Use B<Y>our or cB<O>mmand to launch
multiple files.

=head1 QUOTING RULES

C<pfm> adds an extra layer of parsing to filenames and shell commands. It
is important to take notice of the rules that C<pfm> uses.

=for considering In versions prior to 1.93.1, the default escape character was B<\>.

The following six types of input can be distinguished:

=over

=item B<a regular expression> (only the B<I>nclude and eB<X>clude commands)

The input is parsed as a regular expression.

=item B<a time> (e.g. the B<T>ime or B<I>nclude - B<B>efore commands)

Characters not in the set C<[0-9.]> are removed from the input.

=item B<a literal pattern> (only the B<F>ind command)

The input is taken literally.

=item B<not a filename or shell command> (e.g. in B<A>ttribute or B<U>id)

The input is taken literally.

=item B<a filename> (e.g. in B<C>opy or tarB<G>et).

First of all, tilde expansion is performed.

Next, any C<=[1-8evp]> character sequence is expanded to the corresponding
value.

At the same time, any C<=[^1-8evp]> character sequence is just replaced
with the character itself.

Finally, if the filename is to be processed by C<pfm>, it is taken literally;
if it is to be handed over to a shell, all metacharacters are replaced I<escaped>.

=item B<a shell command> (e.g. in cB<O>mmand or B<P>rint)

First of all, tilde expansion is performed.

Next, any C<=[1-8evp]> character sequence is expanded to the corresponding
value, I<with shell metacharacters escaped>.

At the same time, any C<=[^1-8evp]> character sequence is just replaced
with the character itself.

=back

In short:

=over

=item

C<pfm> always escapes shell metacharacters in expanded B<=2>
I<etc.> constructs.

=item

In filenames entered, shell metacharacters are taken literally.

=item

In shell commands entered, metacharacters that you want to be taken
literally must be escaped one extra time.

=back

Examples:

=begin html

<table border="0" cellspacing="4" align="center">
<tr><td colspan="3"><hr /><td></tr>
<tr>
	<td>char(s) wanted in filename&nbsp;&nbsp;&nbsp;</td>
	<td>char(s) to type in filename&nbsp;&nbsp;&nbsp;</td>
	<td>char(s) to type in shell command&nbsp;&nbsp;&nbsp;</td>
</tr>
<tr><td colspan="3"><hr /><td></tr>
<tr>
	<td><i>any non-metachar</i></td>
	<td><i>that char</i></td>
	<td><i>that char</i></td>
</tr>
<tr>
	<td>\</td>
	<td>\</td>
	<td>\\ or '\'</td>
</tr>
<tr>
	<td>&quot;</td>
	<td>&quot;</td>
	<td>\&quot; <b>or</b> '&quot;'</td>
</tr>
<tr>
	<td>=</td>
	<td>==</td>
	<td>==</td>
</tr>
<tr>
	<td><i>space</i></td>
	<td><i>space</i></td>
	<td>\\<i>space</i>  <b>or</b> '<i>space</i>'</td>
</tr>
<tr>
	<td><i>filename</i></td>
	<td>=2</td>
	<td>=2</td>
</tr>
<tr>
	<td>\2</td>
	<td>\2</td>
	<td>\\2 <b>or</b> '\2'</td>
</tr>
<tr>
	<td>=2</td>
	<td>==2</td>
	<td>==2</td>
</tr>
<tr><td colspan="3"><hr /><td></tr>
</table>

=end html

=begin roff

.in
.TS
l | l l.
_
T{
char(s) wanted in filename
T}	T{
char(s) to type in filename
T}	T{
char(s) to type in shell command
T}
_
.\" great. *roff wants even more backslashes. so much for clarity.
\fIany non-metachar\fP	\fIthat char\fP	\fIthat char\fP
\\	\\	\\\\ \fBor\fR '\\'
"	"	\\" \fBor\fR '"'
\&=	==	==
\fIspace\fP	\fIspace\fP	\\\fIspace\fP \fBor\fR '\fIspace\fP'
\fIfilename\fP	=2	=2
\\2	\\2	\\\\2 \fBor\fR '\\2'
=2	==2	==2
_
.TE
.in

=end roff

=head1 MOUSE COMMANDS

When C<pfm> is run in an xterm or other terminal that supports the
use of a mouse, turning on mouse mode (either initially with the
'defaultmousemode' option in the F<.pfmrc> file, or while running using
the B<F12> key) will give mouse access to the following commands:

=begin html

<table border="0" cellspacing="4" align="center" width="70%">
<tr><td colspan="7"><hr /></td></tr>
<tr>
	<th rowspan="3">button</th>
	<th colspan="6">location clicked</th>
</tr>
<tr><td colspan="7"><hr /></td></tr>
<tr>
	<td>pathline</td>
	<td>title/header</td>
	<td>footer</td>
	<td>fileline</td>
	<td>filename</td>
	<td>dirname</td>
</tr>
<tr><td colspan="7"><hr /></td></tr>
<tr>
	<td>1</td>
	<td><i>chdir()</i></td>
	<td>CTRL-U</td>
	<td>CTRL-D</td>
	<td>F8</td>
	<td><b>S</b>how</td>
	<td><b>S</b>how</td>
</tr>
<tr>
	<td>2</td>
	<td>c<b>O</b>mmand</td>
	<td>PgUp</td>
	<td>PgDn</td>
	<td><b>S</b>how</td>
	<td>ENTER</td>
	<td><i>new window</i></td>
</tr>
<tr>
	<td>3</td>
	<td>c<b>O</b>mmand</td>
	<td>PgUp</td>
	<td>PgDn</td>
	<td><b>S</b>how</td>
	<td>ENTER</td>
	<td><i>new window</i></td>
</tr>
<tr><td colspan="7"><hr /><td></tr>
<tr>
	<td>wheel up</td>
	<td colspan="6" align="center"><i>three lines up</i></td>
</tr>
<tr>
	<td>wheel down</td>
	<td colspan="6" align="center"><i>three lines down</i></td>
</tr>
<tr><td colspan="7"><hr /></td></tr>
</table>

=end html

=begin roff

.in +2n
.TS
c | c s s s s s
^ | l l l l l l
c | l l l l l l
c | l l l l l l
c | l l l l l l
c | c s s s s s
c | c s s s s s.
_
\0button	location clicked
_
\^	pathline	T{
title/
.br
header
T}	footer	fileline	filename	dirname
_
1	\fIchdir()\fR	CTRL-U	CTRL-D	F8	\fBS\fPhow	\fBS\fPhow
2	c\fBO\fPmmand	PgUp	PgDn	\fBS\fPhow	ENTER	\fInew win\fP\0
3	c\fBO\fPmmand	PgUp	PgDn	\fBS\fPhow	ENTER	\fInew win\fP
_
up	\fIthree lines up\fP
down	\fIthree lines down\fP
_
.TE
.in

=end roff

The cursor will I<only> be moved when the title, header or footer is
clicked, or when changing directory. The mouse wheel also works and
moves the cursor three lines per notch, or one line if shift is pressed.

Clicking button 1 on the current directory path will chdir() up to the
clicked ancestor directory. If the current directory was clicked, or the
device name, it will act like a B<M>ore - B<S>how command.

Clicking button 2 on a directory name will open a new pfm terminal window.

Mouse use will be turned off during the execution of commands, unless
'mouseturnoff' is set to 'no' in F<.pfmrc>. Note that setting this to
'no' means that your (external) commands (like your pager and editor)
will receive escape codes when the mouse is clicked.

=head1 WORKING DIRECTORY INHERITANCE

Upon exit, C<pfm> will save its current working directory in the file
F<$HOME/.pfm/cwd>, and its swap directory, if any, in F<$HOME/.pfm/swd>.
This enables the user to have the calling process (shell) "inherit"
C<pfm>'s current working directory, and to reinstate the swap directory
upon the next invocation.  To achieve this, you may call C<pfm> using a
function or alias like the following:

Example for ksh(1), bash(1) and zsh(1):

    pfm() {
        if [ -s ~/.pfm/swd ]; then
            swd=-s"`cat ~/.pfm/swd`"
        fi
        # providing $swd is optional
        env pfm $swd "$@"
        if [ -s ~/.pfm/cwd ]; then
            cd "`cat ~/.pfm/cwd`"
            rm -f ~/.pfm/cwd
        fi
    }

Example for csh(1) and tcsh(1):

    alias pfm ':                                \
    if (-s ~/.pfm/swd) then                     \
        set swd=-s"`cat ~/.pfm/swd`"            \
    endif                                       \
    : providing $swd is optional                \
    env pfm $swd \!*                            \
    if (-s ~/.pfm/cwd) then                     \
        cd "`cat ~/.pfm/cwd`"                   \
        rm -f ~/.pfm/cwd                        \
    endif'

=head1 ENVIRONMENT

=over

=item B<ANSI_COLORS_DISABLED>

Detected as an indication that ANSI coloring escape sequences should not
be used.

=item B<CDPATH>

A colon-separated list of directories specifying the search path when
changing directories. There is always an implicit B<.> entry at the start
of this search path.

=item B<EDITOR>

The editor to be used for the B<E>dit command. Overridden by VISUAL.

=item B<LC_ALL>

=item B<LC_COLLATE>

=item B<LC_CTYPE>

=item B<LC_MESSAGES>

=item B<LC_NUMERIC>

=item B<LC_TIME>

=item B<LANG>

Determine locale settings, most notably for collation sequence, messages
and date/time format. See locale(7).

=item B<PAGER>

Identifies the pager with which to view text files. Defaults to less(1)
for Linux systems or more(1) for Unix systems.

=item B<PERL_RL>

Indicate whether and how the readline prompts should be highlighted.
See Term::ReadLine(3pm). If unset, a good guess is made based on your
config file 'framecolors[]' setting.

=item B<PFMRC>

Specify a location of an alternate F<.pfmrc> file. If unset, the default
location F<$HOME/.pfm/.pfmrc> is used. The cwd- and history-files cannot
be displaced in this manner, and will always be located in the directory
F<$HOME/.pfm/>.

=item B<PRINTER>

May be used to specify a printer to print to using the B<P>rint command.

=item B<SHELL>

Your default login shell, spawned by B<M>ore - sB<H>ell.

=item B<VISUAL>

The editor to be used for the B<E>dit command. Overrides EDITOR.

=back

=head1 FILES

The directory F<$HOME/.pfm/> and files therein. A number of input histories
and the current working directory on exit are saved to this directory.

The default location for the config file is F<$HOME/.pfm/.pfmrc>.

=head1 EXIT STATUS

=over

=item 0

Success (could also be a user requested exit, I<e.g.> after
B<--help> or B<--version>).

=item 1

Invalid commandline option.

=item 2

No valid layout found in the F<.pfmrc> file.

=back

=head1 DIAGNOSIS

If C<pfm> reports that your config file might be outdated, you might be
missing some of the newer configuration options (or default values for
these). Try the following command and compare the new config file with
your original one:

    env PFMRC=~/.pfm/.pfmrc-new pfm

To prevent the warning from occurring again, update the '## Version' line.

=head1 BUGS and WARNINGS

C<Term::ReadLine::Gnu> does not allow a half-finished line to be aborted by
pressing B<ESC>. For most commands, you will need to clear the half-finished
line. You may use the terminal kill character (usually B<CTRL-U>) for this
(see stty(1)).

The author once almost pressed B<ENTER> when logged in as root and with
the cursor on the file F</sbin/reboot>. You have been warned.

The smallest terminal size supported is 80x24. The display will be messed
up if you resize your terminal window to a smaller size.

=head1 VERSION

=for roff
.PP \" display the 'pertains to'-macro
.Vp \*(Vw

=head1 AUTHOR and COPYRIGHT

=for roff
.PP \" display the authors
.\" the \(co character only exists in groff
.ie \n(.g .ds co \(co
.el       .ds co (c)
.ie \n(.g .ds e' \('e
.el       .ds e' e\*'
..
Copyright \*(co 1999-\*(Yr, Ren\*(e' Uittenbogaard
(ruittenb@users.sourceforge.net).
.PP

=for html
Copyright &copy; Ren&eacute; Uittenbogaard
(ruittenb&#64;users.sourceforge.net).

All rights reserved. This program is free software; you can redistribute
it and/or modify it under the terms described by the GNU General Public
License version 2.

This program was based on PFMS<.>COM version 2.32, originally written for
MS-DOS by Paul R. Culley and Henk de Heer. The name 'pfm' was adopted
with kind permission of the original authors.

=head1 SEE ALSO

The documentation on PFMS<.>COM. The manual pages for chmod(1), file(1),
less(1), locale(7), lpr(1), touch(1), vi(1).

For developers: Term::Screen(3pm), Term::ScreenColor(3pm),
Term::ReadLine(3pm), App::PFM::Abstract(3pm), App::PFM::Application(3pm),
App::PFM::Browser(3pm), App::PFM::CommandHandler(3pm), App::PFM::Config(3pm),
App::PFM::Directory(3pm), App::PFM::History(3pm), App::PFM::Job(3pm),
App::PFM::Screen(3pm), App::PFM::State(3pm) and App::PFM::Util(3pm).

The pfm project page: http://sourceforge.net/projects/p-f-m/

=cut

# vim: set tabstop=4 shiftwidth=4:
