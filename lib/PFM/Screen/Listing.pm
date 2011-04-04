#!/usr/bin/env perl
#
##########################################################################
# @(#) PFM::Screen::Listing 0.01
#
# Name:			PFM::Screen::Listing.pm
# Version:		0.01
# Author:		Rene Uittenbogaard
# Created:		1999-03-14
# Date:			2010-03-27
#

##########################################################################

=pod

=head1 NAME

PFM::Screen::Listing

=head1 DESCRIPTION

PFM class for displaying a PFM::Directory object on the screen.

=head1 METHODS

=over

=cut

##########################################################################
# declarations

package PFM::Screen::Listing;

use base 'PFM::Abstract';

use constant {
	NAMETOOLONGCHAR => '+',
	HIGHLIGHT_OFF	=> 0,
	HIGHLIGHT_ON	=> 1,
};

use constant FILETYPEFLAGS => {
	# ls(1)
	x => '*',
	d => '/',
	l => '@',
	p => '|',
   's'=> '=',
	D => '>',
	w => '%',
	# tcsh(1)
	b => '#',
	c => '%',
	n => ':',
	# => '+', # Hidden directory (AIX only) or context dependent (HP/UX only)
};

my ($_pfm,
	$_layout, $_cursorcol, @_layoutfields, @_layoutfieldswithinfo,
	$_filerecordcol, $_currentformatline, $_currentformatlinewithinfo);

##########################################################################
# private subs

=item _init()

Initializes new instances. Called from the constructor.

=cut

sub _init {
	my ($self, $pfm) = @_;
	$_pfm = $pfm;
}

# TODO
sub _validate_layoutnum {
	my ($self, $num) = @_;
	# TODO columnlayouts
	while ($num > $#columnlayouts) {
		$num -= @columnlayouts;
	}
	return $num;
}

=item _highlightline()

Turns highlight on/off on the line with the cursor.

=cut

sub _highlightline { # true/false
	my ($self, $on) = @_;
	my $screen = $_pfm->screen;
	my $linecolor;
	# TODO currentline
	$screen->at($currentline + $screen->BASELINE, $_filerecordcol);
	if ($on == HIGHLIGHT_ON) {
		$linecolor =
			$_pfm->config->{framecolors}{$_pfm->state->{color_mode}}{highlight};
		$screen->bold()			if ($linecolor =~ /bold/);
		$screen->reverse()		if ($linecolor =~ /reverse/);
#		$screen->underline()	if ($linecolor =~ /under(line|score)/);
		$screen->term()->Tputs('us', 1, *STDOUT)
							if ($linecolor =~ /under(line|score)/);
	}
	$screen->putcolored($linecolor, fileline(\%currentfile, @layoutfields));
	applycolor($currentline + $BASELINE, $FILENAME_SHORT, %currentfile);
	$screen->reset()->normal()->at($currentline + $BASELINE, $cursorcol);
}

##########################################################################
# constructor, getters and setters

=item layout()

Getter/setter for the current layout number. If this is called to set
the current layout, it will do all the necessary changes.

=cut

sub layout {
	my ($self, $value) = @_;
	if (defined $value) {
		my $screen = $_pfm->screen;
		$_layout = $self->_validate_layoutnum($value);
		$self->makeformatlines();
		$self->reformat();
		$screen->set_deferred_refresh($screen->R_SCREEN);
	}
	return $_layout;
}

=item cursorcol()

Getter/setter for the current cursor column on-screen.

=cut

sub cursorcol {
	my ($self, $value) = @_;
	$_cursorcol = $value if defined $value;
	return $_cursorcol;
}

=item filerecordcol()

Getter/setter for the current cursor column on-screen.

=cut

sub filerecordcol {
	my ($self, $value) = @_;
	$_filerecordcol = $value if defined $value;
	return $_filerecordcol;
}

=item layoutfields()

Getter/setter for the array with layout fields.

=cut

sub layoutfields {
	my ($self, @value) = @_;
	@_layoutfields = @value if @value;
	return \@_layoutfields;
}

=item layoutfieldswithinfo()

Getter/setter for the array with layout fields, with the diskinfo
field included.

=cut

sub layoutfieldswithinfo {
	my ($self, @value) = @_;
	@_layoutfieldswithinfo = @value if @value;
	return \@_layoutfieldswithinfo;
}

=item currentformatline()

Getter/setter for the string defining the format of a file record.

=cut

sub currentformatline {
	my ($self, $value) = @_;
	$_currentformatline = $value if defined $value;
	return $_currentformatline;
}

=item currentformatlinewithinfo()

Getter/setter for the string defining the format of a file record,
with the diskinfo field included.

=cut

sub currentformatlinewithinfo {
	my ($self, $value) = @_;
	$_currentformatlinewithinfo = $value if defined $value;
	return $_currentformatlinewithinfo;
}

##########################################################################
# public subs

=item highlight_off()

=item highlight_on()

Turns highlight on/off on the line with the cursor.

=cut

sub highlight_off() {
	$_[0]->_highlightline(HIGHLIGHT_OFF);
}

sub highlight_on() {
	$_[0]->_highlightline(HIGHLIGHT_ON);
}

=item select_next_layout()

Switch the directory listing to the next configured layout.

=cut

sub select_next_layout {
	return $_[0]->layout($_layout + 1);
}

=item show()

Displays the directory listing.

=cut

sub show {
	my $self = shift;
	my $contents  = $_pfm->directory->showncontents;
	my $baseindex = $_pfm->browser->baseindex;
	my $baseline  = $_screen->BASELINE;
	foreach my $i ($baseindex .. $baseindex+$_screen->screenheight) {
		$_screen->at($i+$baseline-$baseindex, $_filerecordcol);
		unless ($i > $#contents) {
			$_screen->puts(fileline($contents[$i]));
			# TODO
			applycolor($i+$baseline-$baseindex, $FILENAME_SHORT, %{$contents[$i]});
		} else {
			$_screen->puts(
				' 'x($_screen->screenwidth - $_screen->diskinfo->infolength));
		}
	}
}

sub fileline {
	my ($self, $currentfile) = @_;
	return formatted($_currentformatline, @{$currentfile}{@_layoutfields});
}

##########################################################################

=back

=head1 SEE ALSO

pfm(1), PFM::Screen(3pm).

=cut

1;

# vim: set tabstop=4 shiftwidth=4:
