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

		$a ? %$a : (),

		# plot parameter
		rootx	=> 0,
		rooty	=> 0,
		width	=> 0,
		height	=> 0,

		bounds	=> [
			{ # xaxis
				min	=> undef,
				max	=> undef,
			},
			{ # yaxis
				min	=> undef,
				max	=> undef,
			},
		],

		# local data
		matrix	=> undef,
		path	=> undef,

	}, ref $proto || $proto;
}

sub set_source {
	my( $self, $source, $xcol, $ycol ) = @_;

	#print STDERR ref($self) ."::set_source\n";
	$self->{source} = $source;
	$self->set_view_bounds;
	@{$self->{column}} = ( $xcol, $ycol );
	$self->{matrix} = undef;
	$self->{path} = undef;
}

sub set_size {
	my( $self, $rx, $ry, $w, $h ) = @_;

	#print STDERR ref($self) ."::set_size $rx $ry $w $h\n";
	$self->{matrix} = undef;
	$self->{rootx} = $rx,
	$self->{rooty} = $ry,
	$self->{width} = $w;
	$self->{height} = $h;
}

sub get_source_bounds {
	my( $self, $dim ) = @_;

	# TODO: rotate?
	$self->{source}->bounds( $self->{column}[$dim] );
}

sub set_view_bounds {
	my( $self, $dim, $min, $max ) = @_;

	# TODO: rotate?
	$self->{bounds}[$dim] = {
		min	=> $min,
		max	=> $max,
	};
	$self->{matrix} = undef;
}

sub get_view_bounds {
	my( $self, $dim ) = @_;

	@{$self->{bounds}[$dim]}{qw( min max )};
}

sub build_matrix {
	my( $self ) = @_;

	my( $rx, $ry, $w, $h ) = @{$self}{qw(rootx rooty width height)};

	my( $xmin, $xmax ) = $self->get_view_bounds(0);
	my $xlen = $xmax - $xmin || 1;
	my $xdelta = $self->{source}->delta( $self->{column}[0] );

	my( $ymin, $ymax ) = $self->get_view_bounds(1);
	my $ylen = $ymax - $ymin || 1;
	my $ydelta = $self->{source}->delta( $self->{column}[1] );

	#print STDERR ref($self)."::matrix $xlen, $xdelta, $ylen, $ydelta\n";
	Cairo::Matrix->init( 
		$w / $xlen,		0, 
		0,			-$h/$ylen, 
		$rx-$w * ($xmin+$xdelta)/$xlen,
					$ry+$h * ($ymax+$ydelta)/$ylen );

}

sub translate {
	my( $self, $cr ) = @_;

	$self->{matrix} = $self->build_matrix; # TODO: build_matrix_rotate
	$cr->transform( $self->{matrix} );
}

sub path {
	my( $self, $cr ) = @_;

	$self->{path} ||= $self->build_path( $cr );
	$self->{path};
}

sub build_path {
	my( $self, $cr ) = @_;
	croak "virtual method";
}

# TODO: alternate build_path methods for sources other than arrays of hashes

sub dump_coord {
	my( $self, $cr ) = @_;

	my( $xmin, $xmax ) = $self->get_source_bounds(0);
	my( $ymin, $ymax ) = $self->get_source_bounds(1);

	print STDERR ref($self),"::coords: ", join(" ", map { int( ($_||0) +0.5) } (
		$cr->user_to_device( $xmin||0, $ymin||0 ),
		$cr->user_to_device( $xmax||0, $ymax||0 ) 
	) ), "\n";
}


sub plot {
	my( $self, $cr ) = @_;

	#print STDERR ref($self) ."::plot\n";
	$cr->save;

	$cr->save;
	$self->translate( $cr );
	#$self->dump_coord( $cr );
	$cr->append_path( $self->path( $cr ) );
	$cr->restore;

	$cr->set_source_rgb( @{$self->{color}} );
	$self->do_plot( $cr );
	$cr->restore;
}

sub do_plot {
	my( $self, $cr ) = @_;
	croak "virtual method";
}


1;
