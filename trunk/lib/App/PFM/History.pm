#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::History 0.25
#
# Name:			App::PFM::History
# Version:		0.25
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-09-01
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
	MAXHISTSIZE  => 70,
	FILENAME_CWD => 'cwd',
	FILENAME_SWD => 'swd',
	H_COMMAND    => 'history_command',
	H_MODE       => 'history_mode',
	H_PATH       => 'history_path',
	H_REGEX      => 'history_regex',
	H_TIME       => 'history_time',
	H_PERLCMD    => 'history_perlcmd',
};

our %EXPORT_TAGS = (
	constants => [ qw(
		H_COMMAND
		H_MODE
		H_PATH
		H_REGEX
		H_TIME
		H_PERLCMD
	) ]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm);

##########################################################################
# private subs

=item _init(App::PFM::Application $pfm)

Initializes this instance by instantiating a Term::ReadLine object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
	$self->{_keyboard} = new Term::ReadLine('pfm');
	if (ref $self->{_keyboard}->Features) {
		$self->{_features} = $self->{_keyboard}->Features;
	} else {
		# Term::ReadLine::Zoid does not return a hash reference
		$self->{_features} = { $self->{_keyboard}->Features };
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

=item _set_term_history(array @histlines)

Uses the history list to initialize keyboard history in Term::ReadLine.
This fails silently if our current variant of Term::ReadLine doesn't
support the setHistory() method.

=cut

sub _set_term_history {
	my ($self, @histlines) = @_;
	if ($self->{_features}->{setHistory}) {
		$self->{_keyboard}->SetHistory(@histlines);
	}
	return $self->{_keyboard};
}

##########################################################################
# constructor, getters and setters

=item keyboard()

Getter for the Term::ReadLine object.

=cut

sub keyboard {
	my ($self) = @_;
	return $self->{_keyboard};
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

=item write( [ bool $finishing ] )

Writes the histories to files in the config directory.
The argument I<finishing> indicates that the final message
should be shown without delay.

=cut

sub write {
	my ($self, $finishing) = @_;
	my $failed;
	my $screen = $_pfm->screen;
	unless ($finishing) {
		$screen->at(0,0)->clreol()
			->set_deferred_refresh($screen->R_MENU);
	}
	foreach (keys %{$self->{_histories}}) {
		if (open HISTFILE, '>'.$_pfm->config->CONFIGDIRNAME."/$_") {
			print HISTFILE join "\n", @{$self->{_histories}{$_}}, '';
			close HISTFILE;
		} elsif (!$failed) {
			$screen->putmessage("Unable to save (part of) history: $!");
			$failed++; # warn only once
		}
	}
	unless ($failed) {
		$screen->putmessage(
			'History written successfully' . ($finishing ? "\n" : ''));
	}
	unless ($finishing) {
		$screen->error_delay();
	}
}

=item write_dirs()

Writes the current directory and swap directory to files in
the config directory.

=cut

sub write_dirs {
	my ($self) = @_;
	my $configdirname = $_pfm->config->CONFIGDIRNAME;
	my $swap_state	  = $_pfm->state('S_SWAP');
	
	if (open CWDFILE, ">$configdirname/".FILENAME_CWD) {
		print CWDFILE $_pfm->state->directory->path, "\n";
		close CWDFILE;
	} else {
		$_pfm->screen->putmessage(
			"Unable to create $configdirname/".FILENAME_CWD.": $!\n"
		);
	}
	if (defined($swap_state) && $_pfm->config->{swap_persistent} &&
		open SWDFILE,">$configdirname/".FILENAME_SWD)
	{
		print SWDFILE $swap_state->directory->path, "\n";
		close SWDFILE;
	} else {
		unlink "$configdirname/".FILENAME_SWD;
	}
}

=item input(hashref { history => string $history [, prompt => string $prompt ]
[, default_input => string $default_input ] [, history_input => string
$history_input ] [, pushfilter => string $pushfilter ] } )

Displays I<prompt> and prompts for input from the keyboard. The parameter
I<history> selects the history list to use and may use the B<H_*> constants
as defined by App::PFM::History. The string I<default_input> is offered,
while the string I<history_input> is offered as the most-recent history item.
If the user's input is not equal to I<pushfilter>, the input is pushed
onto the appropriate history list.

=cut

sub input {
	my ($self, $options) = @_;
	my ($history, $input);
	$history = $self->{_histories}{$options->{history}};
	local $SIG{INT} = 'IGNORE'; # do not interrupt pfm
	if (length $options->{history_input} and 
		(@$history == 0 or
		(@$history > 0 && $options->{history_input} ne ${$history}[-1])))
	{
		push(@$history, $options->{history_input});
	}
	$self->_set_term_history(@$history);
	$input = $self->{_keyboard}->readline(
		$options->{prompt}, $options->{default_input});
	if ($input =~ /\S/ and @$history > 0 and
		$input ne ${$history}[-1] and
		$input ne $options->{pushfilter})
	{
		push(@$history, $input);
	}
	shift(@$history) while ($#$history > MAXHISTSIZE);
	return $input;
}

=item setornaments(string $colorstring)

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
		$self->{_keyboard}->ornaments($cols[0] . ',me,,');
	}
}

=item handleresize()

Tells the readline library that the screen size has changed.

=cut

sub handleresize {
	my ($self) = @_;
	$self->{_keyboard}->resize_terminal();
}

##########################################################################

=back

=head1 CONSTANTS

This package provides the B<H_*> constants which indicate the different
types of input histories.
They can be imported with C<use App::PFM::History qw(:constants)>.

=over

=item H_COMMAND

The history of shell commands entered, I<e.g.> for cB<O>mmand.

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

    $self->input({ history => H_PATH });

=head1 SEE ALSO

pfm(1).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
