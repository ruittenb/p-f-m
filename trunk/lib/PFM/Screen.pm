#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen 2010-03-27 v0.01
#
# Name:			PFM::Screen.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
# Requires:		Term::ScreenColor
# Description:	PFM class used for controlling the screen.
#

package PFM::Screen;

use base 'Term::ScreenColor';

use PFM::Screen::Frame;

use constant {
	PATHLINE		=> 1,
	BASELINE		=> 3,
	DISKINFOLINE	=> 4,
	DIRINFOLINE		=> 9,
	MARKINFOLINE	=> 15,
	USERINFOLINE	=> 21,
	DATEINFOLINE	=> 22,
#	TERM_RAW		=> 0,
#	TERM_COOKED		=> 1,
#	MOUSE_OFF		=> 0,
#	MOUSE_ON		=> 1,
#	ALTERNATE_OFF	=> 0,
#	ALTERNATE_ON	=> 1,
};

my ($_frame, $_screenwidth, $_screenheight);

##########################################################################
# private subs

sub _init {
	my $self = shift;
	$_frame = new PFM::Screen::Frame();
}

##########################################################################
# constructor, getters and setters

sub new {
	my $type = shift;
	$type = ref($type) || $type;
	my $self = {};
	bless($self, $type);
	$self->_init();
	return $self;
}

sub screenwidth {
	my ($self, $value) = @_;
	$_screenwidth = $value if defined $value;
	return $_screenwidth;
}

sub screenheight {
	my ($self, $value) = @_;
	$_screenheight = $value if defined $value;
	return $_screenheight;
}

##########################################################################
# public subs

sub recalculate_dimensions {
	my $self = shift;
	if ($self->rows()) { $_screenheight = $self->rows() - BASELINE - 2 }
	if ($self->cols()) { $_screenwidth  = $self->cols() }
	return $self;
}

sub stty_raw {
	my $self = shift;
	system qw(stty raw -echo);
	$self->noecho();
}

sub stty_cooked {
	my $self = shift;
	system qw(stty -raw echo);
	$self->echo();
}

sub mouse_enable {
	my $self = shift;
	print "\e[?9h";
	return $self;
}

sub mouse_disable {
	my $self = shift;
	print "\e[?9l";
	return $self;
}

sub alternate_on {
	my $self = shift;
	print "\e[?47h";
	return $self;
}

sub alternate_off {
	my $self = shift;
	print "\e[?47l";
	return $self;
}

sub putcentered {
	my ($self, $string) = @_;
	$self->puts(' ' x (($_screenwidth - length $string)/2) . $string);
}

sub draw_frame {
	my $self = shift;
	$_frame->draw();
	return $self;
}

##########################################################################

1;

# vim: set tabstop=4 shiftwidth=4:
