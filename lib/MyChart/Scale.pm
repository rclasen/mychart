package MyChart::Scale;
use warnings;
use strict;
use Carp;

sub new {
	my( $proto, $a ) = @_;

	# ATTENTION: some defaults are overwritten from MyChart::add_scale()
	bless {
		position	=> 1,		# 0=zero, 1=left/bottom, 2=right/top, undef=hide
		inside		=> undef,	# undef=auto, 0=outside 1=inside

		min		=> undef,	# override range guessing
		max		=> undef,	# override range guessing
		invert		=> 0,		# count from max to min

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

		scale_label	=> undef,
		scale_label_fg	=> [0,0,0],
		scale_label_font	=> 'Sans 8',

		( $a ? %$a : () ),

		plot		=> [],		# plots using this scale
		plot_size	=> undef,	# plot area size
		context		=> undef,	# cairo context

		# cached from parameter
		label_fmt_sub	=> undef,	# function to format labels

		# cached from plot data
		bounds		=> undef,	# min,max from user/plots
		label_dims	=> undef,	# size of labels
		space		=> undef,	# space needed for tics+labels

		# cached from device size + plot data
		ticlist		=> undef,	# tics + prebuilt labels

	}, ref $proto || $proto;
}

# 0=horiz, 1=vertical
sub orientation { croak "virtual method"; } # TODO: get rid of this

sub position {
	$_[0]->{position};
}

sub inside {
	$_[0]->{inside};
}

sub add_plot {
	my $self = shift;
	push @{$self->{plot}}, @_;

	# clear caches
	$self->{bounds} = undef;
	$self->{label_dims} = undef;
	$self->{space} = undef;
	$self->{ticlist} = undef;
}

sub set_bounds {
	my( $self, $min, $max ) = @_;
	$self->{min} = $min;
	$self->{max} = $max;

	# clear caches
	$self->{bounds} = undef;
	$self->{label_dims} = undef;
	$self->{space} = undef;
	$self->{ticlist} = undef;
}

sub flush_bounds {
	my( $self ) = @_;

	$self->{bounds} = undef;
	$self->{ticlist} = undef;
}

sub build_bounds {
	my( $self ) = @_;

	my( $min, $max ) = @{$self}{qw( min max )};

	if( ! defined $min || ! defined $max ){
		my( $amin, $amax );

		foreach my $plot (@{$self->{plot}}){
			my $dim = $self->orientation;
			$dim = $dim ? 0 : 1 if $plot->rotate;

			my( $pmin, $pmax, $pdelta ) =
				$plot->get_source_bounds( $dim );

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
		my $dim = $self->orientation;
		$dim = $dim ? 0 : 1 if $plot->rotate;

		$plot->set_view_bounds( $dim,
			$min, $max, $self->{invert} );
	}

	( $min, $max );
}

sub get_bounds {
	my( $self ) = @_;

	$self->{bounds} ||= [ $self->build_bounds ];
	@{$self->{bounds}};
}

sub build_fmt {
	my( $self, $fmt ) = @_;

	if( ! defined $fmt ){
		# fall back to perls default stringification
		return sub { $_[0] };

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

sub set_plot_size {
	my( $self, $plot_size ) = @_;

	$self->{plot_size} = [ @$plot_size ];

	# clear caches
	$self->{ticlist} = undef;
}

sub set_context {
	my( $self, $context ) = @_;

	$self->{context} = $context;

	# clear caches
	$self->{ticlist} = undef;
}


sub fmt_label {
	my( $self, $val ) = @_;

	my $fmt = $self->{label_fmt_sub} ||= $self->build_fmt( $self->{label_fmt} );
	$fmt->( $val );
}

sub build_pango {
	my( $self, $font, $val ) = @_;

	$self->{context}->save;
	$self->{context}->rotate( 3.141 / 2 );

	my $fd = Gtk2::Pango::FontDescription->from_string( $font );
	my $l = Gtk2::Pango::Cairo::create_layout( $self->{context} );
	$l->set_font_description( $fd );
	$l->set_text( $val );

	$self->{context}->restore;
	$l;
}

sub build_label {
	my( $self, $val ) = @_;

	$self->build_pango( $self->{label_font}, $self->fmt_label( $val ) );
}

sub build_label_dims {
	my( $self ) = @_;

	my @size = map {
		[ $self->build_label( $_ )->get_pixel_size ];

	} ref $self->{label_fmt} eq 'ARRAY'
		? @{$self->{label_fmt}}
		: $self->get_bounds;

	my @max;
	foreach my $v ( @size ){
		foreach my $d ( 0, 1 ){
			if( ! defined($max[$d]) || $max[$d] < $v->[$d] ){
				$max[$d] = $v->[$d]
			}
		}
	}

	#print STDERR "MyChart::Scale::build_label_dims @max (no rotate)\n";

	# ( along_axis, orthogonal_to_axis )
	$self->{label_rotate}
		? reverse @max
		: @max;
}

sub build_space {
	my( $self ) = @_;

	$self->{label_dims} ||= [ $self->build_label_dims ];

	return [ $self->{tic_len}
		+ int( 1.1* $self->{label_dims}[1] )
		+ $self->{label_space},
		int( 1.1* $self->{label_dims}[0] / 2 ),
		int( 1.1* $self->{label_dims}[0] / 2 ),
		];
}

sub get_space {
	my( $self ) = @_;

	$self->{space} ||= $self->build_space;
	@{$self->{space}};
}

# TODO: deal with multiple scales on same side of axes.

# calculate tics (amount, positions)
sub build_ticlist {
	my( $self, $devlen ) = @_;

	my( $min, $max ) = $self->get_bounds;
	my $ulen = $max - $min;

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

			my $dval = int($devlen * ($val - $min) / $ulen );
			($dval *= -1) += $devlen if $self->{invert};

			#print STDERR "tic_at $dval $val $lval\n";
			unshift @tics, [
				$dval,
				$lval,
				$self->build_label( $lval ),
			];
		};

	} elsif( $self->{tic_num} ){
		my $ustep = $ulen / $self->{tic_num};
		my $dstep = $devlen / $self->{tic_num};
		#print STDERR "tic_num steps: $dstep $ustep\n";

		foreach my $i ( 0 .. ($self->{tic_num}-1) ){
			my $val = $min + $ustep * $i;
			my $dval = int( $dstep * $i );
			($dval *= -1) += $devlen if $self->{invert};

			#print STDERR "tic_num $dval $val\n";
			push @tics, [
				$dval,
				$val,
				$self->build_label( $val ),
			];
		}

	} elsif( $self->{tic_step} ){
		my $uoffset = $min % $self->{tic_step};

		my $first = int($min/$self->{tic_step});
		$first++ if $uoffset;
		my $num = int($max/$self->{tic_step}) - $first;

		my $dstep = $self->{tic_step} * $devlen / $ulen;
		my $doffset = $uoffset * $devlen / $ulen;
		#print STDERR "tic_step num=$num offsets: $doffset $uoffset, dstep: $dstep\n";

		foreach my $i ( 0 .. $num){
			my $val = $min + $uoffset + $self->{tic_step} * $i;
			my $dval = int( $doffset + $dstep * $i );
			($dval *= -1) += $devlen if $self->{invert};

			#print STDERR "tic_step $dval $val\n";
			push @tics, [
				$dval,
				$val,
				$self->build_label( $val ),
			];
		}

	} else {
		# print as many labels as possible
		$self->{label_dims} ||= [ $self->build_label_dims ];

		# device coords
		my $lsize = $self->{label_dims}[0];
		my $num = int( $devlen  /
			($lsize + $self->{label_space} )
		);

		# data coords
		my $ustep = $ulen / $num;
		my $dstep = $devlen / $num;

		#print STDERR "tic_label_dims $lsize, num=$num, steps: $dstep $ustep\n";

		foreach my $i ( 0 .. ($num ) ){
			my $val = $min + $ustep * $i;
			my $dval = int( $dstep * $i );
			($dval *= -1) += $devlen if $self->{invert};

			#print STDERR "tic_label_dims $dval $val\n";
			push @tics, [
				$dval,
				$val,
				$self->build_label( $val ),
			];
		}

	}
	#print STDERR "tics: ", scalar @tics, "\n";
	return \@tics;
}

sub draw { croak "virtual method"; };


1;
