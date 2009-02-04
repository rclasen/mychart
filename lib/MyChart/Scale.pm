package MyChart::Scale;
use warnings;
use strict;
use Carp;

sub new {
	my( $proto, $a ) = @_;
	bless { 
		dimension	=> 1,		# 0=horiz, 1=vertical
		position	=> 1,		# 0=zero, 1=left/bottom, 2=right/top, undef=hide
		inside		=> undef,	# undef=auto, 0=outside 1=inside

		min		=> undef,	# override range guessing
		max		=> undef,	# override range guessing
		invert		=> 0,		# TODO: count from max to min

		tic_at		=> undef,	# 1. use predefined list of X
		tic_num		=> 0,		# or 2. number of tics to draw
		tic_step	=> 0,		# or 3. OR draw tic each X
		tic_len		=> 5,
		tic_fg		=> [0,0,0],
		# tic_num is quessed when neither tic_num, tic_step,
		# tic_at is set. It takes the label size into account.
		tic_space	=> 4,		# spece between tic + label

		grid		=> 0,
		grid_fg		=> [0,0,0],

		label_skip	=> 0,		# print label each $step tic
		label_fmt	=> undef,	# undef=guess, "fmt", sub, []
		label_fg	=> [0,0,0],
		label_font	=> 'Sans 8',
		label_rotate	=> 0,		# 0=horiz, 1=vertical
		label_space	=> 4,		# space between label + margin

		ax_label	=> undef,
		ax_label_fg	=> [0,0,0],
		ax_label_font	=> 'Sans 8',

		( $a ? %$a : () ),

		plot		=> [],		# plots using this scale
		bounds		=> undef,	# min,max from user/plots
		size		=> undef,	# space needed for tics+labels
		label_fmt_sub	=> undef,	# function to format labels
		label_size	=> undef,	# size of labels
		ticlist		=> undef,	# tics + prebuilt labels

	}, ref $proto || $proto;
}

sub dimension {
	$_[0]->{dimension};
}

sub position {
	$_[0]->{position};
}

sub inside {
	$_[0]->{inside};
}

sub add_plot {
	my $self = shift;
	push @{$self->{plot}}, @_;

	$self->{bounds} = undef;
	$self->{size} = undef;
	$self->{label_size} = undef;
	$self->{ticlist} = undef;
}

# TODO: clear caches
sub set_bounds {
	my( $self, $min, $max ) = @_;
	$self->{min} = $min;
	$self->{max} = $max;

	$self->{bounds} = undef;
	$self->{size} = undef;
	$self->{label_size} = undef;
	$self->{ticlist} = undef;
}

sub build_bounds {
	my( $self ) = @_;

	my( $min, $max ) = @{$self}{qw( min max )};

	if( ! defined $min || ! defined $max ){
		my( $amin, $amax );

		foreach my $plot (@{$self->{plot}}){
			my( $pmin, $pmax, $pdelta ) = 
				$plot->get_source_bounds( $self->dimension );

			#print STDERR ref($self) 
			#	."::build_bounds: plot $pmin, $pmax, $pdelta\n";

			$pmin -= $pdelta;
			$pmax -= $pdelta;

			if( ! defined $amin || $pmin < $amin ){
				$amin = $pmin;
			}
			if( ! defined $amax || $pmax > $amax ){
				$amax = $pmax;
			}
		}

		if( ! defined $min ){
			$min = $amin ||0;
		}

		if( ! defined $max ){
			$max = $amax ||0;
		}
	}

	#print STDERR ref($self) ."::build_bounds: $min, $max\n";
	foreach my $plot (@{$self->{plot}}){
		$plot->set_view_bounds( $self->dimension, $min, $max );
	}

	[ $min, $max ];
}

sub get_bounds {
	my( $self ) = @_;

	$self->{bounds} ||= $self->build_bounds;
	@{$self->{bounds}};
}

sub build_fmt {
	my( $self, $fmt ) = @_;

	if( ! defined $fmt ){
		# TODO quess fmt
		return sub { sprintf( '%f', $_[0] ) };

	} elsif( ! ref $fmt ){
		return sub { sprintf( $fmt, $_[0] ) };

	} elsif( ref $fmt eq 'ARRAY' ){
		return sub { $_[0]; };

	} elsif( ref $fmt eq 'CODE' ){
		return $fmt;

	} else {
		croak "invalid label_fmt";
	}
}

sub fmt_label {
	my( $self, $val ) = @_;

	my $fmt = $self->{label_fmt_sub} ||= $self->build_fmt( $self->{label_fmt} );
	$fmt->( $val );
}

sub build_label {
	my( $self, $cr, $val ) = @_;

	# TODO: label_rotate
	my $fd = Gtk2::Pango::FontDescription->from_string( $self->{label_font} );
	my $l = Gtk2::Pango::Cairo::create_layout( $cr );
	$l->set_font_description( $fd );
	$l->set_text( $self->fmt_label( $val ) );
	$l;
}

sub build_label_size {
	my( $self, $cr ) = @_;

	my( $a, $b ) = ref $self->{label_fmt} eq 'ARRAY' 
		? ($self->{label_fmt}[0], $self->{label_fmt}[-1] )
		: $self->get_bounds;

	my $la = $self->build_label( $cr, $a );
	my $lb = $self->build_label( $cr, $b );

	my @sa = $la->get_pixel_size;
	my @sb = $lb->get_pixel_size;

	[ ($sa[0] > $sb[0] ? $sa[0] : $sb[0]),
		($sa[1] > $sb[1] ? $sa[1] : $sb[1]) ];
}

sub build_size {
	my( $self, $cr ) = @_;

	$self->{label_size} ||= $self->build_label_size( $cr );
	my $dim = $self->{dimension} == 0 ? 1 : 0;

	return $self->{tic_len} 
		+ int( 1.05* $self->{label_size}[$dim]  )
		+ $self->{label_space};
}

sub get_size {
	my( $self, $cr ) = @_;

	$self->{size} ||= $self->build_size( $cr );
}

# TODO: calculate tics (amount, positions)
# TODO: draw draw axis label, tics, tic labels, grid

sub build_ticlist {
	my( $self, $cr, $devmin, $devmax ) = @_;

	my $devlen = $devmax - $devmin;
	my( $min, $max ) = $self->get_bounds;
	#print STDERR "ticlist: $devmin, $devmax, $devlen\n";

	my @tics; # = [ devdelta, label ],

	if( $self->{tic_at} ){
		my $labels = $self->{label_fmt} if ref $self->{label_fmt} eq 'ARRAY';

		for( my $i = $#{$self->{tic_at}}; $i >= 0; --$i ){
			my $val = $self->{tic_at}[$i];

			$val >= $min && $val <= $max
				or next;

			my $lval = $labels 
				? $labels->[$i]
				: $val;
			defined $lval or next;

			my $dval = int($devlen * ($val - $min) / ($max - $min) );

			#print STDERR "tic_at $dval $val $lval\n";
			unshift @tics, [
				$dval,
				$self->build_label( $cr, $lval ),
			];
		};

	} elsif( $self->{tic_num} ){
		my $ustep = ($max - $min) / $self->{tic_num};
		my $dstep = $devlen / $self->{tic_num};
		#print STDERR "tic_num steps: $dstep $ustep\n";

		foreach my $i ( 0 .. ($self->{tic_num}-1) ){
			my $dval = int( $dstep * $i );
			my $val = $min + $ustep * $i;

			#print STDERR "tic_num $dval $val\n";
			push @tics, [
				$dval,
				$self->build_label( $cr, $val ),
			];
		}

	} elsif( $self->{tic_step} ){
		my $num = int($max/$self->{tic_step}) -
			int($min/$self->{tic_step} +0.5) -1;
		my $uoffset = $min + ($min % $self->{tic_step});

		my $dstep = $self->{tic_step} * $devlen / ($max - $min);
		my $doffset = $dstep * ($self->{tic_step} - $min % $self->{tic_step})
			/ $self->{tic_step};
		#print STDERR "tic_step num=$num offsets: $doffset $uoffset, dstep: $dstep\n";

		foreach my $i ( 0 .. $num){
			my $dval = int( $doffset + $dstep * $i );
			my $val = $uoffset + $self->{tic_step} * $i;

			#print STDERR "tic_step $dval $val\n";
			push @tics, [
				$dval,
				$self->build_label( $cr, $val ),
			];
		}

	} else {
		# print as many labels as possible
		$self->{label_size} ||= $self->build_label_size( $cr );

		# device coords
		my $size = $self->{label_size}[ $self->{dimension} == 0 ?  0 : 1 ];
		my $num = int( ($devlen - $self->{label_space} ) /
			($size + 2*$self->{label_space} )
		);

		# data coords
		my $ustep = ($max - $min) / $num;
		my $dstep = $devlen / $num;

		#print STDERR "tic_label_size $size, num=$num, steps: $dstep $ustep\n";

		foreach my $i ( 0 .. ($num ) ){
			my $dval = int( $dstep * $i );
			my $val = $min + $ustep * $i;

			#print STDERR "tic_label_size $dval $val\n";
			push @tics, [
				$dval,
				$self->build_label( $cr, $val ),
			];
		}

	}
	#print STDERR "tics: ", scalar @tics, "\n";
	return \@tics;
}

sub plot_vertical {
	my( $self, $cr, $l, $t, $r, $b ) = @_;

	my( $x1, $ltr );
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

	my( $x2, $x3 );
	if( $ltr ){
		$x2 = $x1 + $self->{tic_len};
		$x3 = $x2 + $self->{tic_space};
	} else {
		$x2 = $x1 - $self->{tic_len};
		$x3 = $x2 - $self->{tic_space};
	}

	my $tics = $self->{ticlist} ||= $self->build_ticlist( $cr, $t, $b );
	foreach my $tic ( @$tics ){
		$cr->move_to( $x1, $b - $tic->[0] +0.5 );
		$cr->line_to( $x2, $b - $tic->[0] +0.5 );
	}
	$cr->set_source_rgb( @{$self->{tic_fg}} );
	$cr->set_line_width( 1 );
	$cr->stroke;

	foreach my $tic ( @$tics ){
		my $label = $tic->[1];
		my( $w, $h ) = $label->get_pixel_size;

		
		my $x4 = $x3 + ( $ltr ? 0 : -$w );
		$cr->move_to( $x4, $b - $tic->[0] - $h/2 );
		$cr->set_source_rgb( @{$self->{label_fg}} );
		Gtk2::Pango::Cairo::show_layout( $cr, $label );
	}
}

sub plot_horizontal {
	my( $self, $cr, $l, $t, $r, $b ) = @_;

	my( $y1, $ttb );
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

	my( $y2, $y3 );
	if( $ttb ){
		$y2 = $y1 + $self->{tic_len};
		$y3 = $y2 + $self->{tic_space};
	} else {
		$y2 = $y1 - $self->{tic_len};
		$y3 = $y2 - $self->{tic_space};
	}

	my $tics = $self->{ticlist} ||= $self->build_ticlist( $cr, $l, $r );

	foreach my $tic ( @$tics ){
		$cr->move_to( $l + $tic->[0] +0.5, $y1 );
		$cr->line_to( $l + $tic->[0] +0.5, $y2 );
	}
	$cr->set_source_rgb( @{$self->{tic_fg}} );
	$cr->set_line_width( 1 );
	$cr->stroke;

	foreach my $tic ( @$tics ){
		my $label = $tic->[1];
		my( $w, $h ) = $label->get_pixel_size;

		
		my $y4 = $y3 + ( $ttb ? 0 : $h );
		$cr->move_to( $l + $tic->[0] - $w/2, $y4 );
		$cr->set_source_rgb( @{$self->{label_fg}} );
		Gtk2::Pango::Cairo::show_layout( $cr, $label );
	}

}

sub plot {
	my( $self, $cr, $l, $t, $r, $b ) = @_;

	$self->{size} = undef;
	$self->{label_size} = undef;
	$self->{ticlist} = undef;

	if( $self->{dimension} == 0 ){
		$self->plot_horizontal( $cr, $l, $t, $r, $b );
	} else {
		$self->plot_vertical( $cr, $l, $t, $r, $b );
	}
}


1;
