#
# Copyright (c) 2008 Rainer Clasen
#
# This program is free software; you can redistribute it and/or modify
# it under the terms described in the file LICENSE included in this
# distribution.
#

package MyChart::Plot::Area;
use base 'MyChart::Plot';
use strict;
use warnings;

sub new {
	my( $proto, $a ) = @_;

	my $self = $proto->SUPER::new({
		fill_color	=> undef,
		fill_alpha1	=> 0.6,
		fill_alpha2	=> 0.2,

		%$a,
	});

	$self->{fill_color} ||= $self->{color};

	$self;
}

sub build_path_loh {
	my( $self ) = @_;

	my $cr = $self->{context};
	my @col = ( $self->{xcol}, $self->{ycol} );
	my $dat = $self->{source}->list;

	my( $xmin, $xmax ) = $self->get_source_bounds(0);

	$cr->move_to( $xmin, 0 );
	my( $lx, $ly );
	foreach( @$dat ){
		my( $x, $y ) = @{$_}{@col};
		if( defined $y ){
			if( ! defined $ly ){
				$cr->line_to( $x, 0 );
			}
			$cr->line_to( $x, $y );

		} else {
			if( defined $ly ){
				$cr->line_to( $lx, 0 );
			}
		};
		( $lx, $ly ) = ( $x, $y );
	}
	if( defined $ly && $ly ){
		$cr->line_to( $xmax, 0 );
	}
	$cr->close_path;

	$cr->copy_path;
}

sub do_plot {
	my( $self ) = @_;


	my $cr = $self->{context};

	my $dat = $self->{source}->list;
	if( @$dat < 4000 ){
		# TODO: workaround ->fill being killed by xserver for unknown reason

		my( $l, $t, $r, $b ) = @{ $self->{plot_size} };
		my @d = (
			[ $l, $r ],
			[ $b, $t ],
		);
		my @r = $self->{rotate} ? reverse @d : @d;
		foreach(0..1){
			@{$r[$_]} = reverse @{$r[$_]} if $self->{bounds}[$_]{invert};
		}

		my @coord = $self->{rotate} ? (
			$d[0][0], $d[1][0],
			$d[0][1], $d[1][0],
		) : (
			$d[0][0], $d[1][0],
			$d[0][0], $d[1][1],
		);

		my $pat = Cairo::LinearGradient->create( @coord );
		$pat->add_color_stop_rgba( 0, @{$self->{fill_color}},
			$self->{fill_alpha1} );
		$pat->add_color_stop_rgba( 1, @{$self->{fill_color}},
			$self->{fill_alpha2} );
		$cr->set_source( $pat );
		$cr->fill_preserve;
	}

	$cr->set_source_rgba( @{$self->{color}}, $self->{alpha} );
	$cr->set_line_width( $self->{line_width} );
	$cr->stroke;
}


1;
