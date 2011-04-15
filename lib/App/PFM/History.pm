#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::History 0.22
#
# Name:			App::PFM::History
# Version:		0.22
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-05-28
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
	MAXHISTSIZE	=> 70,
	H_COMMAND	=> 'history_command',
	H_MODE		=> 'history_mode',
	H_PATH		=> 'history_path',
	H_REGEX		=> 'history_regex',
	H_TIME		=> 'history_time',
	H_PERLCMD	=> 'history_perlcmd',
};

our @EXPORT = qw(H_COMMAND H_MODE H_PATH H_REGEX H_TIME H_PERLCMD);

our ($_pfm, $_keyboard);

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
	my $escape;
	$_pfm      = $pfm;
	$_keyboard = new Term::ReadLine('pfm');
	if (ref $_keyboard->Features) {
		$self->{_features} = $_keyboard->Features;
	} else {
		# Term::ReadLine::Zoid does not return a hash reference
		$self->{_features} = { $_keyboard->Features };
	}
	# some defaults
	$self->{_histories} = {
		H_COMMAND,	[ 'du -ks * | sort -n'	],
		H_MODE,		[ '755', '644'			],
		H_PATH,		[ '/', $ENV{HOME}		],
		H_REGEX,	[ '\.jpg$', '\.mp3$'	],
		H_TIME,		[],
		H_PERLCMD,	[],
	};
}

=item _set_term_history()

Uses the history list to initialize keyboard history in Term::ReadLine.
This fails silently if our current variant of Term::ReadLine doesn't
support the setHistory() method.

=cut

sub _set_term_history {
	my ($self, @histlines) = @_;
	if ($self->{_features}->{setHistory}) {
		$_keyboard->SetHistory(@histlines);
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
	my ($self) = @_;
	my $hfile;
	foreach (keys %{$self->{_histories}}) {
		$hfile = $_pfm->config->CONFIGDIRNAME . "/$_";
		if (-s $hfile and open (HISTFILE, $hfile)) {
			chomp( @{$self->{_histories}{$_}} = <HISTFILE> );
			close HISTFILE;
		}
	}
}

=item write()

Writes the histories to files in the config directory.

=cut

sub write {
	my ($self) = @_;
	my $failed;
	my $screen = $_pfm->screen;
	$screen->at(0,0)->clreol();
	foreach (keys %{$self->{_histories}}) {
		if (open HISTFILE, '>'.$_pfm->config->CONFIGDIRNAME."/$_") {
			print HISTFILE join "\n", @{$self->{_histories}{$_}}, '';
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
	my ($self) = @_;
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

sub input {
	# $history, $prompt [, $default_input [, $history_input [, $filter ]]]
	my ($self, $history, $prompt, $input, $histpush, $pushfilter) = @_;
	$history = $self->{_histories}{$history};
	$prompt ||= '';
	$input  ||= '';
	local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
	if (length $histpush and 
		(@$history == 0 or
		(@$history > 0 && $histpush ne ${$history}[-1])))
	{
		push(@$history, $histpush);
	}
	$self->_set_term_history(@$history);
	$input = $_keyboard->readline($prompt, $input);
	if ($input =~ /\S/ and @$history > 0 and
		$input ne ${$history}[-1] and
		$input ne $pushfilter)
	{
		push(@$history, $input);
	}
	shift(@$history) while ($#$history > MAXHISTSIZE);
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
