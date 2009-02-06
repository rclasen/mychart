package MyChart::Scale::Vertical;
use warnings;
use strict;
use base 'MyChart::Scale';
use Carp;
use Math::Trig qw/ pi /;

sub orientation { 1; }

sub build_label_dims {
	my( $self ) = @_;

	reverse $self->SUPER::build_label_dims;
}

# draw axis label, tics, tic labels, grid
# TODO: draw axis label
# TODO: reduce code duplication
sub draw {
	my( $self ) = @_;

	my( $l, $t, $r, $b ) = @{ $self->{plot_size} };
	my $cr = $self->{context};

	my( $x1, $ltr ); # axis coord, left-to-right?
	if( $self->{position} == 3 ){
		return; # invisible, do nothing

	} elsif( $self->{position} == 2 ){
		$x1 = $r;
		$ltr = ! $self->{inside};

	} elsif( $self->{position} == 1 ){
		$x1 = $l;
		$ltr = $self->{inside};
	
	} else { # position == 0
		# TODO: zero axis scale

	}

	my( $x2, $x3 ); # tic-end, label border
	if( $ltr ){
		$x2 = $x1 + $self->{tic_len};
		$x3 = $x2 + $self->{tic_space};
	} else {
		$x2 = $x1 - $self->{tic_len};
		$x3 = $x2 - $self->{tic_space};
	}

	my $tics = $self->{ticlist} ||= $self->build_ticlist( $b - $t );

	# grid
	if( $self->{grid} ){
		foreach my $tic ( @$tics ){
			$cr->move_to( $l, $b - $tic->[0] +0.5 );
			$cr->line_to( $r, $b - $tic->[0] +0.5 );
		}
		$cr->set_source_rgba( @{$self->{grid_fg}}, 0.5 );
		$cr->set_line_width( 1 );
		$cr->stroke;
	}

	# tics
	foreach my $tic ( @$tics ){
		$cr->move_to( $x1, $b - $tic->[0] +0.5 );
		$cr->line_to( $x2, $b - $tic->[0] +0.5 );
	}
	$cr->set_source_rgb( @{$self->{tic_fg}} );
	$cr->set_line_width( 1 );
	$cr->stroke;

	# label
	foreach my $tic ( @$tics ){
		my $label = $tic->[2];
		my( $w, $h );
		
		my $x4 = $x3; # label root (top left)
		if( $self->{label_rotate} ){
			( $h, $w ) = $label->get_pixel_size;
			$x4 += $w;

		} else {
			( $w, $h ) = $label->get_pixel_size;

		}
		$x4 -= $w unless $ltr;

		$cr->move_to( $x4, $b - $tic->[0] - $h/2 );
		$cr->save;
		$cr->rotate( pi / 2 ) if $self->{label_rotate};
		$cr->set_source_rgb( @{$self->{label_fg}} );
		Gtk2::Pango::Cairo::update_layout( $cr, $label );
		Gtk2::Pango::Cairo::show_layout( $cr, $label );
		$cr->restore;
	}

}


1;
