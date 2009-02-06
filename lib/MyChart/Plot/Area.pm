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

	$proto->SUPER::new({
		color_alpha	=> 0.6,
		color_alpha2	=> 0.2,

		%$a,
	});
}

sub build_path_loh {
	my( $self ) = @_;

	my $cr = $self->{context};
	my @col = ( $self->{xcol}, $self->{ycol} );
	my $dat = $self->{source}->list;

	my( $xmin, $xmax ) = $self->get_source_bounds(0);
	my( $ymin, $ymax ) = $self->get_view_bounds(1); 
	# TODO: don't use view limits. They end up in the cached path and
	# result in broken plots when the view limits are changed.

	$cr->move_to( $xmin, $ymin );
	#print join( ' ', $xmin, $ymin ),"\n";
	my( $lx, $ly );
	foreach( @$dat ){
		my( $x, $y ) = @{$_}{@col};
		if( defined $y ){
			if( ! defined $ly ){
				$cr->line_to( $x, $ymin );
				#print join( ' ', $x, $ymin ),"\n";
			}
			$cr->line_to( $x, $y );
			#print join( ' ', $x, $y ),"\n";

		} else {
			if( defined $ly ){
				$cr->line_to( $lx, $ymin );
				#print join( ' ', $lx, $ymin ),"\n";
			}
		};
		( $lx, $ly ) = ( $x, $y );
	}
	if( defined $ly && $ly > $ymin ){
		$cr->line_to( $xmax, $ymin );
		#print join( ' ', $xmax, $ymin ),"\n";
	}
	$cr->close_path;
	#print "area path close\n";

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
		print STDERR "gradient @coord\n";
		$pat->add_color_stop_rgba( 0, @{$self->{color}}, $self->{color_alpha} );
		$pat->add_color_stop_rgba( 1, @{$self->{color}}, $self->{color_alpha2} );
		$cr->set_source( $pat );
		$cr->fill_preserve;
	}

	$cr->set_source_rgb( @{$self->{color}} );
	$cr->set_line_width( $self->{line_width} );
	$cr->stroke;
}


1;
