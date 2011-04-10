#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::History 0.08
#
# Name:			App::PFM::History
# Version:		0.08
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-04-27
#

##########################################################################

=pod

=head1 NAME

App::PFM::History

=head1 DESCRIPTION

PFM History class. Reads and writes history files, holds the histories
in memory, and coordinates how Term::ReadLine handles them.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package App::PFM::History;

use base qw(App::PFM::Abstract Exporter);

use Term::ReadLine;

use strict;

use constant {
	H_COMMAND	=> 'history_command',
	H_MODE		=> 'history_mode',
	H_PATH		=> 'history_path',
	H_REGEX		=> 'history_regex',
	H_TIME		=> 'history_time',
	H_PERLCMD	=> 'history_perlcmd',
};

our @EXPORT = qw(H_COMMAND H_MODE H_PATH H_REGEX H_TIME H_PERLCMD);

my ($_pfm, $_keyboard,
	@_command_history,
	@_mode_history,
	@_path_history,
	@_regex_history,
	@_time_history,
	@_perlcmd_history,
);

my %HISTORIES = (
	history_command	=> \@_command_history,
	history_mode	=> \@_mode_history,
	history_path	=> \@_path_history,
	history_regex	=> \@_regex_history,
	history_time	=> \@_time_history,
	history_perlcmd	=> \@_perlcmd_history,
);

my $MAXHISTSIZE	= 70;
my $CWDFILENAME	= 'cwd';
my $SWDFILENAME	= 'swd';

##########################################################################
# private subs

=item _init()

Initializes this instance by instantiating a Term::ReadLine object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm      = $pfm;
	$_keyboard = new Term::ReadLine('pfm');
}

=item _set_term_history()

Uses the history list to initialise keyboard history in
Term::ReadLine. This fails silently if our current
implementation of Term::ReadLine doesn't support the setHistory()
method.

=cut

sub _set_term_history {
	my $self = shift;
	if ($_keyboard->Features->{setHistory}) {
		$_keyboard->SetHistory(@_);
	}
	return $_keyboard;
}

##########################################################################
# constructor, getters and setters

=item keyboard()

Getter for the Term::ReadLine object.

=cut

sub keyboard {
	return $_keyboard;
}

##########################################################################
# public subs

=item read()

Reads the histories from the files in the config directory.

=cut

sub read {
	my $self = shift;
	my $hfile;
	my $escape = $_pfm->config->{e};
	# some defaults
	@_command_history = ('du -ks * | sort -n', "man ${escape}1");
	@_mode_history	 = ('755', '644');
	@_path_history	 = ('/', $ENV{HOME});
	@_regex_history	 = ('\.jpg$');
#	@time_history;
#	@perlcmd_history;
	foreach (keys(%HISTORIES)) {
		$hfile = $_pfm->config->CONFIGDIRNAME . "/$_";
		if (-s $hfile and open (HISTFILE, $hfile)) {
			chomp( @{$HISTORIES{$_}} = <HISTFILE> );
			close HISTFILE;
		}
	}
}

=item write()

Writes the histories to files in the config directory.

=cut

sub write {
	my $self = shift;
	my $failed;
	my $screen = $_pfm->screen;
	$screen->at(0,0)->clreol();
	foreach (keys(%HISTORIES)) {
		if (open HISTFILE, '>'.$_pfm->config->CONFIGDIRNAME."/$_") {
			print HISTFILE join "\n", @{$HISTORIES{$_}}, '';
			close HISTFILE;
		} elsif (!$failed) {
			$screen->putmessage("Unable to save (part of) history: $!");
			$failed++; # warn only once
		}
	}
	$screen->putmessage('History written successfully') unless $failed;
	$screen->error_delay();
	$screen->important_delay() if $failed;
	$screen->set_deferred_refresh($screen->R_MENU);
}

=item write_dirs()

Writes the current directory and swap directory to files in
the config directory.

=cut

sub write_dirs {
	my $self = shift;
	my $configdirname = $_pfm->config->CONFIGDIRNAME;
	my $swap_state	  = $_pfm->state($_pfm->S_SWAP);
	
	if (open CWDFILE, ">$configdirname/$CWDFILENAME") {
		print CWDFILE $_pfm->state->directory->path, "\n";
		close CWDFILE;
	} else {
		$_pfm->screen->putmessage(
			"Unable to create $configdirname/$CWDFILENAME: $!\n"
		);
	}
	if (defined($swap_state) && $_pfm->config->{swap_persistent} &&
		open SWDFILE,">$configdirname/$SWDFILENAME")
	{
		print SWDFILE $swap_state->directory->path, "\n";
		close SWDFILE;
	} else {
		unlink "$configdirname/$SWDFILENAME";
	}
}

=item input()

Prompts for input from the keyboard; pushes this input onto
the appropriate history.

=cut

sub input { # $history, $prompt, [$default_input]
	local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
	my ($self, $history, $prompt, $input) = @_;
	$history = $HISTORIES{$history};
	$prompt ||= '';
	$input  ||= '';
	$self->_set_term_history(@$history);
	$input = $_keyboard->readline($prompt, $input);
	if ($input =~ /\S/ and $input ne ${$history}[-1]) {
		push (@$history, $input);
		shift (@$history) if ($#$history > $MAXHISTSIZE);
	}
	return $input;
}

=item setornaments()

Determines from the config file settings which ornaments (bold, italic,
underline) should be used for the command prompt, then instructs
Term::ReadLine to use these.

=cut

sub setornaments {
	my ($self, $color) = @_;
	my @cols;
	$color ||=
		$_pfm->config->{framecolors}{$_pfm->screen->color_mode}{message};
	unless (exists $ENV{PERL_RL}) {
		# this would have been nice, however,
		# readline processes only the first (=most important) capability
		push @cols, 'mr' if ($color =~ /reverse/);
		push @cols, 'md' if ($color =~ /bold/);
		push @cols, 'us' if ($color =~ /under(line|score)/);
#		$kbd->ornaments(join(';', @cols) . ',me,,');
		$_keyboard->ornaments($cols[0] . ',me,,');
	}
}

=item handleresize()

Tells the readline library that the screen size has changed.

=cut

sub handleresize {
	my ($self) = @_;
	$_keyboard->resize_terminal();
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the B<H_*> constants which indicate the different
types of input histories. They are:

=over

=item H_COMMAND

The history of shell commands entered, I<e.g.> for the B<O> command.

=item H_MODE

The history of file modes (permission bits).

=item H_PATH

The history of file- and directory paths entered, I<e.g.> entered for
the B<M>ore - B<S>how command.

=item H_REGEX

The history of regular expressions entered.

=item H_TIME

The history of times entered, I<e.g.> for the B<T> command.

=item H_PERLCMD

The history of Perl commands entered for the B<@> command.

=back

An input line may be stored in one of the histories by providing
one of these constants to input() I<e.g.>

    $self->input(H_PATH);

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
