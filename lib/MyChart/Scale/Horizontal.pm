package MyChart::Scale::Horizontal;
use warnings;
use strict;
use base 'MyChart::Scale';
use Carp;
use Math::Trig qw/ pi /;

sub orientation { 0; }

# draw axis label, tics, tic labels, grid
# TODO: draw axis label
# TODO: reduce code duplication
sub draw {
	my( $self ) = @_;

	my( $l, $t, $r, $b ) = @{ $self->{plot_size} };
	my $cr = $self->{context};

	my( $y1, $ttb ); # axis-coord, top-to-bottom?
	if( $self->{position} == 3 ){
		return; # invisible, do nothing

	} elsif( $self->{position} == 2 ){
		$y1 = $t;
		$ttb = $self->{inside};

	} elsif( $self->{position} == 1 ){
		$y1 = $b;
		$ttb = ! $self->{inside};

	} else { # position == 0
		# TODO: zero axis scale

	}

	my( $y2, $y3 ); # tic-end, label border
	if( $ttb ){
		$y2 = $y1 + $self->{tic_len};
		$y3 = $y2 + $self->{tic_space};
	} else {
		$y2 = $y1 - $self->{tic_len};
		$y3 = $y2 - $self->{tic_space};
	}

	my $tics = $self->{ticlist} ||= $self->build_ticlist( $r - $l );

	# grid
	if( $self->{grid} ){
		foreach my $tic ( @$tics ){
			$cr->move_to( $l + $tic->[0] +0.5, $t );
			$cr->line_to( $l + $tic->[0] +0.5, $b );
		}
		$cr->set_source_rgba( @{$self->{grid_fg}}, 0.5 );
		$cr->set_line_width( 1 );
		$cr->stroke;
	}

	# tics
	foreach my $tic ( @$tics ){
		$cr->move_to( $l + $tic->[0] +0.5, $y1 );
		$cr->line_to( $l + $tic->[0] +0.5, $y2 );
	}
	$cr->set_source_rgb( @{$self->{tic_fg}} );
	$cr->set_line_width( 1 );
	$cr->stroke;

	# label
	foreach my $tic ( @$tics ){
		my $label = $tic->[2];
		my( $x, $w, $h );

		if( $self->{label_rotate} ){
			( $h, $w ) = $label->get_pixel_size;
			$x = $l + $tic->[0] + $w/2;

		} else {
			( $w, $h ) = $label->get_pixel_size;
			$x = $l + $tic->[0] - $w/2;
		}

		my $y4 = $y3 + ( $ttb ? 0 : $h ); # label root (top left)
		$cr->move_to( $x, $y4 );

		$cr->save;
		$cr->rotate( pi / 2 ) if $self->{label_rotate};
		$cr->set_source_rgb( @{$self->{label_fg}} );
		Gtk2::Pango::Cairo::update_layout( $cr, $label );
		Gtk2::Pango::Cairo::show_layout( $cr, $label );
		$cr->restore;

	}

}


1;
