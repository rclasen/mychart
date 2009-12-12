#
# Copyright (c) 2008 Rainer Clasen
#
# This program is free software; you can redistribute it and/or modify
# it under the terms described in the file LICENSE included in this
# distribution.
#

# TODO: pod

package MyChart::Plot;
use strict;
use warnings;
use Carp;
use Math::Trig qw/ pi /;

sub new {
	my( $proto, $a ) = @_;

	bless {
		# config
		legend	=> undef,	# text to print in legend
		color	=> [ 0,0,0 ],

		# data source properties
		source	=> undef,
		column	=> [
			$a->{xcol},	# xaxis
			$a->{ycol},	# yaxis
		],

		# chart properties
		context	=> undef,

		# scale properties:
		rotate	=> 0,

		$a ? %$a : (),

		# plot parameter
		plot_size	=> undef,

		# view parameter
		bounds	=> [{			# xaxis
			min	=> undef,
			max	=> undef,
			invert	=> 0,
		}, {				# yaxis
			min	=> undef,
			max	=> undef,
			invert	=> 0,
		}],

		# local data
		matrix	=> undef,
		path	=> undef,

	}, ref $proto || $proto;
}

sub rotate { $_[0]->{rotate}; }

sub flush {
	my( $self ) = @_;

	$self->{matrix} = undef;
	$self->{path} = undef;
}

sub set_source {
	my( $self, $source, $xcol, $ycol ) = @_;

	#print STDERR ref($self) ."::set_source\n";
	$self->{source} = $source;
	$self->set_view_bounds; # TODO: parameter
	@{$self->{column}} = ( $xcol, $ycol );

	$self->{matrix} = undef;
	$self->{path} = undef;
}

sub set_context {
	my( $self, $context ) = @_;

	$self->{context} = $context;
}

sub set_plot_size {
	my( $self, $plot_size ) = @_;

	#print STDERR ref($self) ."::set_size $rx $ry $w $h\n";
	$self->{plot_size} = [ @$plot_size ];

	# clear cache:
	$self->{matrix} = undef;
}

sub get_source_bounds {
	my( $self, $dim ) = @_;

	$self->{source}->bounds( $self->{column}[$dim] );
}

sub set_view_bounds {
	my( $self, $dim, $min, $max, $invert ) = @_;

	$self->{bounds}[$dim] = {
		min	=> $min,
		max	=> $max,
		invert	=> $invert,
	};
	$self->{matrix} = undef;
}

sub get_view_bounds {
	my( $self, $dim ) = @_;

	@{$self->{bounds}[$dim]}{qw( min max invert )};
}

sub build_matrix {
	my( $self ) = @_;


	my $cr = $self->{context};

	$cr->save;

	# device coords:
	my( $l, $t, $r, $b ) = @{ $self->{plot_size} };

	my @d = (
		[ $l, $r ],
		[ $b, $t ],
	);
	my @r = $self->{rotate} ? reverse @d : @d;

	# data coords:
	my @u = map { { %$_ }; } @{$self->{bounds}};
	foreach( 0 .. 1 ){
		$u[$_]{delta} = ($self->get_source_bounds($_))[2];
	};

	# invert device axis coords
	foreach( 0 .. 1 ){
		@{$r[$_]} = reverse @{$r[$_]} if $u[$_]{invert};
	}

	# move 0/0 to proper plot corner
	$cr->translate( $d[0][0], $d[1][0] );

	# swap axises by rotating left by 90° and invert proper axis
	if( $self->{rotate} ){
		$cr->rotate( pi/2 );
		$cr->scale( 1, -1 );
	}

	# invert/scale user scale;
	my @scale = (
		($r[0][1]-$r[0][0]) / ( ($u[0]{max} - $u[0]{min})||1 ),
		($r[1][1]-$r[1][0]) / ( ($u[1]{max} - $u[1]{min})||1 ),
	);
	$cr->scale( @scale );

	# data offset:
	$cr->translate( -$u[0]{min} + $u[0]{delta},
		-$u[1]{min} + $u[1]{delta} );

	my $matrix = $cr->get_matrix;
	$cr->restore;
	$matrix;
}


sub translate {
	my( $self ) = @_;

	$self->{matrix} = $self->build_matrix;
	$self->{context}->transform( $self->{matrix} );
}


# TODO: alternate build_path methods for sources other than arrays of hashes
sub build_path_loh {
	my( $self ) = @_;
	croak "virtual method";
}

sub path {
	my( $self ) = @_;

	$self->{path} ||= $self->build_path_loh( $self->{context} );
	$self->{path};
}


sub draw {
	my( $self ) = @_;

	#print STDERR ref($self) ."::draw $self->{ycol}\n";
	my $cr = $self->{context};
	$cr->save;

	$cr->save;
	$self->translate;
	$cr->append_path( $self->path );
	$cr->restore;

	$self->do_plot;
	$cr->restore;
}

sub do_plot {
	my( $self ) = @_;
	croak "virtual method";
}


1;
