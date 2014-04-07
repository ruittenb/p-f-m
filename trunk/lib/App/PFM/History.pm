#!/usr/bin/env perl
#
##########################################################################
# @(#) App::PFM::History 0.40
#
# Name:			App::PFM::History
# Version:		0.40
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2014-04-08
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
use locale;

# for readline completion.
use constant PERL_COMMANDS => [qw(
	accept alarm bind binmode bless break carp case chdir chmod chop chown
	chroot close closedir cluck confess connect continue croak dbmclose
	dbmopen delete die do dump endgrent endhostent endnetent endprotoent
	endpwent endservent eval exec exit fcntl flock fork format given goto
	import ioctl kill last link listen local localtime lock lstat mkdir msgctl
	msgrcv msgsnd my next no open opendir our package pipe pop print printf
	push read recv redo rename require reset return rewinddir rmdir say seek
	seekdir select semctl semop send setgrent sethostent setnetent setpgrp
	setpriority setprotoent setpwent setservent setsockopt shift shmctl shmread
	shmwrite shutdown sleep socket socketpair splice srand stat state study sub
	switch symlink syscall sysread sysseek system syswrite tie tr truncate
	umask undef unlink unpack unshift untie use utime warn when write 
)];

# for readline completion.
# single-character functions like m s y q are not expanded.
use constant PERL_FUNCTIONS => [qw(
	abs atan2 caller cos chr crypt defined each eof exp exists fileno formline
	getc getgrent getgrgid getgrnam gethostbyaddr gethostbyname gethostent
	getlogin getnetbyaddr getnetbyname getnetent getpeername getpgrp getppid
	getpriority getprotobyname getprotobynumber getprotoent getpwent getpwnam
	getpwuid getservbyname getservbyport getservent getsockname getsockopt
	gmtime grep glob new hex index int join keys lc lcfirst length log map
	msgget oct ord pack pos prototype qq qr quotemeta qv qx rand readdir
	readlink readpipe ref reverse rindex scalar semget shmget sin sort split
	sprintf sqrt substr tell telldir tied time times uc ucfirst values vec
	wait waitpid wantarray
)];

# for debugging
use constant PFM_PACKAGE_VARS => [qw(
	$pfm $config $history $os $browser $jobhandler $commandhandler
	$screen $listing $frame $diskinfo $state $directory $currentfile
)];

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
	H_USERGROUP  => 'history_usergroup',
};

our %EXPORT_TAGS = (
	constants => [qw(
		H_COMMAND
		H_MODE
		H_PATH
		H_REGEX
		H_TIME
		H_PERLCMD
		H_USERGROUP
	)]
);

our @EXPORT_OK = @{$EXPORT_TAGS{constants}};

our ($_pfm);

##########################################################################
# private subs

=item I<_init(App::PFM::Application $pfm, App::PFM::Screen $screen,>
I<App::PFM::Config $config)>

Initializes this instance by instantiating a Term::ReadLine object.
Called from the constructor.

=cut

sub _init {
	my ($self, $pfm, $screen, $config) = @_;
	$_pfm = $pfm;
	$self->{_screen}   = $screen;
	$self->{_config}   = $config;
	$self->{_terminal} = Term::ReadLine->new('pfm');
	# completion lists
	$self->{_command_possibilities} = [];
	$self->{_user_possibilities}    = [];
	# features
	if (ref $self->{_terminal}->Features) {
		$self->{_features} = $self->{_terminal}->Features;
	} else {
		# Term::ReadLine::Zoid does not return a hash reference
		$self->{_features} = { $self->{_terminal}->Features };
	}
	# some defaults
	$self->{_histories} = {
		H_COMMAND,  [ 'du -ks * | sort -n'  ],
		H_MODE,     [ '755', '644'          ],
		H_PATH,     [ '/', $ENV{HOME}       ],
		H_REGEX,    [ '\.jpg$', '\.mp3$'    ],
		H_TIME,     [],
		H_PERLCMD,  [],
		H_USERGROUP,[],
	};

	# event hub
	my $on_after_resize_window = sub {
		my ($event) = @_;
		$self->handleresize();
		return;
	};
	$screen->register_listener('after_resize_window', $on_after_resize_window);

	my $on_after_set_color_mode = sub {
		my ($event) = @_;
		$self->setornaments();
		return;
	};
	$screen->register_listener(
		'after_set_color_mode', $on_after_set_color_mode);
	return;
}

=item I<_set_term_history(array @histlines)>

Uses the history list to initialize the input history in Term::ReadLine.
This fails silently if our current variant of Term::ReadLine doesn't
support the setHistory() method.

=cut

sub _set_term_history {
	my ($self, @histlines) = @_;
	if ($self->{_features}->{setHistory}) {
		$self->{_terminal}->SetHistory(@histlines);
	}
	return $self->{_terminal};
}

=item I<_set_input_mode(string $history)>

Applies specific ReadLine library settings, based on the selection
of I<history>, which is one of the B<H_*> constants as defined by
App::PFM::History.

=cut

sub _set_input_mode {
	my ($self, $history) = @_;
	return unless $self->{_features}{attribs};
	my $attribs = $self->{_terminal}->Attribs;
	if ($history eq H_COMMAND) {
		$attribs->{inhibit_completion}              = 0;
		$attribs->{expand_tilde}                    = 1;
		# removed pfm escape char '='
		$attribs->{completer_word_break_characters} = " \t\n\"\\\$'`@><;|&{(";
		$attribs->{directory_completion_hook}       = sub {
			return $self->_directory_expander(@_);
		};
		$attribs->{completion_entry_function}       = undef;
		$attribs->{attempted_completion_function}   = sub {
			return $self->_h_command_completion(@_);
		};
	} elsif ($history eq H_PATH) {
		$attribs->{inhibit_completion}              = 0;
		$attribs->{expand_tilde}                    = 1;
		# removed pfm escape char '='
		$attribs->{completer_word_break_characters} = " \t\n\"\\\$'`@><;|&{(";
		$attribs->{directory_completion_hook}       = sub {
			return $self->_directory_expander(@_);
		};
		$attribs->{completion_entry_function}       = undef;
		$attribs->{attempted_completion_function}   = sub {
			return $self->_h_path_completion(@_);
		};
	} elsif ($history eq H_USERGROUP) {
		$attribs->{inhibit_completion}              = 0;
		$attribs->{expand_tilde}                    = 0;
		# added ':' char
		$attribs->{completer_word_break_characters} = " \t\n\"\\\$'`@><=:;|&{(";
		$attribs->{completion_entry_function}       = undef;
		$attribs->{attempted_completion_function}   = sub {
			return $self->_h_usergroup_completion(@_);
		};
	} elsif ($history eq H_PERLCMD) {
		$attribs->{inhibit_completion}              = 0;
		$attribs->{expand_tilde}                    = 0;
		# removed perl variable sigil '$'
		$attribs->{completer_word_break_characters} = " \t\n\"\\'`@><=;|&{(";
		$attribs->{completion_entry_function}       =
			$attribs->{list_completion_function};
		$attribs->{attempted_completion_function}   = undef;
		$attribs->{completion_word}                 = [
			@{PERL_COMMANDS()}, @{PERL_FUNCTIONS()}, @{PFM_PACKAGE_VARS()}
		];
	} else { # H_REGEX, H_TIME, H_MODE
		$attribs->{inhibit_completion} = 1;
	}
	return;
}

=item I<_h_path_completion(string $text, string $line, int $start, int $end)>

Attempts to complete the path that the user is entering.
Any B<~> character at the beginning is a candidate for username completion.

=cut

sub _h_path_completion {
	my ($self, $text, $line, $start, $end) = @_;
	my $screen = $self->{_screen};
	$screen->set_deferred_refresh($screen->R_SCREEN);
	my $attribs = $self->{_terminal}->Attribs;
	my $head      = substr($line, 0, $start);
	my $textfirst = substr($text, 0, 1);
	# examine the situation
	if ($head eq '' and
		$textfirst eq '~' and
		$text !~ m!/!
	) {
		# If the first character is ~ then do username completion
		$attribs->{completion_append_character} = '/';
		return $self->{_terminal}->completion_matches(
			$text, sub {
				return $self->_user_completion(@_, 1);
			});
	}
	# else do filename completion
	return;
}

=item I<_h_command_completion(string $text, string $line, int $start,>
I<int $end)>

Attempts to complete the command that the user is entering.

=cut

sub _h_command_completion {
	my ($self, $text, $line, $start, $end) = @_;
	my $screen = $self->{_screen};
	$screen->set_deferred_refresh($screen->R_SCREEN);
	my $attribs = $self->{_terminal}->Attribs;
	my $head      = substr($line, 0, $start);
	my $textfirst = substr($text, 0, 1);
	# examine the situation
	if ($head eq '' || $head =~ /\s$/o and
		$textfirst eq '~' and
		$text !~ m!/!
	) {
		# If the current word starts with ~ then do username completion
		$attribs->{completion_append_character} = '/';
		return $self->{_terminal}->completion_matches(
			$text, sub {
				return $self->_user_completion(@_, 1);
			});
	} elsif ($head eq '' || $head =~ /[;&|({]\s*$/o and
		$textfirst ne '~'
	) {
		# If we are at the first word of a command, do command completion
		return $self->{_terminal}->completion_matches(
			$text, sub {
				return $self->_command_completion(@_);
			});
	}
	# else do filename completion
	return;
}

=item I<_h_usergroup_completion(string $text, string $line, int $start,>
I<int $end)>

Attempts to complete the command that the user is entering.

=cut

sub _h_usergroup_completion {
	my ($self, $text, $line, $start, $end) = @_;
	my $screen = $self->{_screen};
	$screen->set_deferred_refresh($screen->R_SCREEN);
	my $attribs = $self->{_terminal}->Attribs;
	my $head      = substr($line, 0, $start);
	my $textfirst = substr($text, 0, 1);
	# examine the situation
	if ($head eq '' and $text !~ /:/) {
		# If the first word is without ':', then do username completion
		$attribs->{completion_append_character} = '';
		return $self->{_terminal}->completion_matches(
			$text, sub {
				return $self->_user_completion(@_, 0);
			});
	} else {
		# After a ':', do groupname completion
		return $self->{_terminal}->completion_matches(
			$text, sub {
				return $self->_group_completion(@_);
			});
	}
	# else do filename completion
	return;
}

=item I<_user_completion(string $text, int $rlstate, bool $tilde)>

Returns one entry of the list of usernames that match the given partial
username. The flag I<tilde> indicates if we are doing path expansion
(which requires tildes) or bare username expansion.

=cut

sub _user_completion {
	my ($self, $text, $rlstate, $tilde) = @_;
	my $attribs = $self->{_terminal}->Attribs;
	my $partial_user;
	$tilde = $tilde ? '~' : '';
	($partial_user = $text) =~ s/^~//; # remove initial ~
	if ($rlstate == 0) {
		$self->{_user_possibilities} = [
			map { $tilde . $_ } $self->_get_user_possibilities($partial_user)
		];
	}
	return pop @{$self->{_user_possibilities}};
}

=item I<_get_user_possibilities(string $partial_user, int $rlstate)>

Finds the list of usernames that match the given partial username.

=cut

sub _get_user_possibilities {
	my ($self, $partial_user) = @_;
	my @possibilities = ();
	my $loop_user;
	endpwent();
	while ($loop_user = getpwent()) {
		if (substr($loop_user, 0, length $partial_user) eq $partial_user) {
			push @possibilities, $loop_user;
		}
	}
	endpwent();
	return @possibilities;
}

=item I<_group_completion(string $text, int $rlstate)>

Returns one entry of the list of groupnames that match the given partial
groupname.

=cut

sub _group_completion {
	my ($self, $text, $rlstate) = @_;
	my $attribs = $self->{_terminal}->Attribs;
	my $partial_group;
	($partial_group = $text) =~ s/^://; # remove initial :
	if ($rlstate == 0) {
		$self->{_group_possibilities} = [
			$self->_get_group_possibilities($partial_group)
		];
	}
	$attribs->{completion_append_character} = '';
	return pop @{$self->{_group_possibilities}};
}

=item I<_get_group_possibilities(string $partial_group, int $rlstate)>

Finds the list of groupnames that match the given partial groupname.

=cut

sub _get_group_possibilities {
	my ($self, $partial_group) = @_;
	my @possibilities = ();
	my $loop_group;
	endgrent();
	while ($loop_group = getgrent()) {
		if (substr($loop_group, 0, length $partial_group) eq $partial_group) {
			push @possibilities, $loop_group;
		}
	}
	endgrent();
	return @possibilities;
}

=item I<_command_completion(string $partial_command, int $rlstate)>

Returns one entry of the list of commands that match the given partial
command.

=cut

sub _command_completion {
	my ($self, $partial_command, $rlstate) = @_;
	my $attribs = $self->{_terminal}->Attribs;
	if ($rlstate == 0) {
		$self->{_command_possibilities} = [
			$self->_get_command_possibilities($partial_command)
		];
	}
	return pop @{$self->{_command_possibilities}};
}

=item I<_get_command_possibilities(string $text, int $rlstate)>

Finds the list of commands that match the given partial command.

=cut

sub _get_command_possibilities {
	my ($self, $partial_cmd) = @_;
	my @possibilities = ();
	my (@entries, $BINDIR);
	foreach my $loop_dir (split /:/, $ENV{PATH}) {
		opendir $BINDIR, $loop_dir;
		@entries = grep {
			-x "$loop_dir/$_" and
			substr($_, 0, length $partial_cmd) eq $partial_cmd

		} readdir $BINDIR;
		push @possibilities, @entries;
		closedir $BINDIR;
	}
	return @possibilities;
}

=item I<_directory_expander(string $path)>

Replaces B<=5/> and B<=9/> at the beginning of a path string with the
actual swap path or previous path.

=cut

sub _directory_expander {
	my ($self) = @_; # 2nd arg modified directly
	my $replaced;
	my $swap_state = $_pfm->state('S_SWAP');
	if ($swap_state) {
		$replaced = ($_[1] =~ s!
			^=5      # swap path escape at beginning
			(?:$|/)  # followed by nothing or /
		!
			$swap_state->directory->path . '/';
		!ex);
		return $replaced if $replaced;
	}
	my $prev_state = $_pfm->state('S_PREV');
	if ($prev_state) {
		$replaced ||= ($_[1] =~ s!
			^=9      # prev path escape at beginning
			(?:$|/)  # followed by nothing or /
		!
			$prev_state->directory->path . '/';
		!ex);
	}
	return $replaced;
}

##########################################################################
# constructor, getters and setters

=item I<terminal()>

Getter for the Term::ReadLine object.

=cut

sub terminal {
	my ($self) = @_;
	return $self->{_terminal};
}

=item I<features()>

Getter for the ReadLine list of features.

=cut

sub features {
	my ($self) = @_;
	return $self->{_features};
}

##########################################################################
# public subs

=item I<read()>

Reads the histories from the files in the config directory.

=cut

sub read {
	my ($self) = @_;
	my $hfile;
	foreach (keys %{$self->{_histories}}) {
		$hfile = $self->{_config}->CONFIGDIRNAME . "/$_";
		if (-s $hfile and open(my $HISTFILE, '<', $hfile)) {
			chomp( @{$self->{_histories}{$_}} = <$HISTFILE> );
			close $HISTFILE;
		}
	}
	return;
}

=item I<write( [ bool $finishing ] )>

Writes the histories to files in the config directory. The argument
I<finishing> is used when shutting down pfm and indicates that the
final message should be shown without delay.

=cut

sub write {
	my ($self, $finishing) = @_;
	my $failed;
	my $screen = $self->{_screen};
	unless ($finishing) {
		$screen->at(0,0)->clreol()
			->set_deferred_refresh($screen->R_MENU);
	}
	foreach (keys %{$self->{_histories}}) {
		if (open my $HISTFILE, '>', $self->{_config}->CONFIGDIRNAME . "/$_") {
			print $HISTFILE join "\n", @{$self->{_histories}{$_}}, '';
			close $HISTFILE;
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
	return;
}

=item I<write_dirs()>

Writes the current directory and swap directory to files in
the config directory.

=cut

sub write_dirs {
	my ($self) = @_;
	my $configdirname = $self->{_config}->CONFIGDIRNAME;
	my $swap_state	  = $_pfm->state('S_SWAP');
	
	if (open my $CWDFILE, '>', $configdirname . '/' . FILENAME_CWD) {
		print $CWDFILE $_pfm->state->directory->path, "\n";
		close $CWDFILE;
	} else {
		$self->{_screen}->putmessage(
			"Unable to create $configdirname/" . FILENAME_CWD . ": $!\n"
		);
	}
	if (defined($swap_state) && $self->{_config}->{swap_persistent} &&
		open my $SWDFILE, '>', $configdirname . '/' . FILENAME_SWD)
	{
		print $SWDFILE $swap_state->directory->path, "\n";
		close $SWDFILE;
	} else {
		unlink "$configdirname/".FILENAME_SWD;
	}
	return;
}

=item I<< input(hashref { history => string $history [, prompt => >>
I<< string $prompt ] [, default_input => string $default_input ] >>
I<< [, history_input => string $history_input ] [, pushfilter => >>
I<< string $pushfilter ] } ) >>

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
	# provide default prompt. Safest way, backwards compatible.
	$options->{prompt} = '' unless defined($options->{prompt});
	if (length $options->{history_input} and 
		(@$history == 0 or
		(@$history > 0 && $options->{history_input} ne ${$history}[-1])))
	{
		push(@$history, $options->{history_input});
	}
	$self->_set_term_history(@$history);
	$self->_set_input_mode($options->{history});
	$input = $self->{_terminal}->readline(
		$options->{prompt}, $options->{default_input});
	if ($input =~ /\S/ and
		$input ne $options->{pushfilter} and
		(@$history == 0 or
		(@$history > 0 && $input ne ${$history}[-1]))
	) {
		push(@$history, $input);
	}
	shift(@$history) while ($#$history > MAXHISTSIZE);
	return $input;
}

=item I<setornaments(string $colorstring)>

Determines from the config file settings which ornaments (bold, italic,
underline) should be used for the command prompt, then instructs
Term::ReadLine to use these.

=cut

sub setornaments {
	my ($self, $color) = @_;
	my @cols;
	$color ||=
		$self->{_config}->{framecolors}{$self->{_screen}->color_mode}{message};
	unless (exists $ENV{PERL_RL}) {
		# this would have been nice, however,
		# readline processes only the first (=most important) capability
		push @cols, 'mr' if ($color =~ /reverse/);
		push @cols, 'md' if ($color =~ /bold/);
		push @cols, 'us' if ($color =~ /under(line|score)/);
#		$kbd->ornaments(join(';', @cols) . ',me,,');
		$self->{_terminal}->ornaments($cols[0] . ',me,,');
	}
	return;
}

=item I<handleresize()>

Tells the readline library that the screen size has changed.

=cut

sub handleresize {
	my ($self) = @_;
	$self->{_terminal}->resize_terminal();
	return;
}

=item I<on_after_parse_config(App::PFM::Event $event)>

Applies the config settings when the config file has been read and parsed.

=cut

sub on_after_parse_config {
	my ($self, $event) = @_;
	# store config
	my $pfmrc        = $event->{data};
	$self->{_config} = $event->{origin};
	# keymap, erase
	system ('stty', 'erase', $pfmrc->{erase}) if defined($pfmrc->{erase});
	# I'd like to test _features for the presence of set_keymap, but
	# it doesn't (?) include information about it.
	# I'd like to test with can('set_keymap'), but Term::ReadLine::Gnu
	# implements it via AUTOLOAD in Term::ReadLine::Gnu::XS.
	if ($self->{_config}{keymap} and
		$self->{_terminal}->ReadLine eq 'Term::ReadLine::Gnu'
	) {
		$self->{_terminal}->set_keymap($self->{_config}{keymap});
	}
	$self->setornaments(
		$self->{_config}{framecolors}{$self->{_screen}->color_mode}{message});
	return;
}

=item I<on_shutdown()>

Called when the application is shutting down. Writes history and directories
to files under F<~/.pfm>.

=cut

sub on_shutdown {
	my ($self) = @_;
	# write current and swap dirs
	$self->write_dirs();
	# write history
	$self->write(1) if $self->{_config}{autowritehistory};
	return;
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

The history of times entered, I<e.g.> for the B<T>ime command.

=item H_USERGROUP

The history of user/group names entered for the B<U>ser command.

=item H_PERLCMD

The history of Perl commands entered for the B<@> command.

=back

An input line may be stored in one of the histories by providing
one of these constants to input() I<e.g.>

    $self->input({ history => H_PATH });

=head1 SEE ALSO

pfm(1), Term::ReadLine(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
