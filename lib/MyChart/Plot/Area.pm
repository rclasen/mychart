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

sub build_path {
	my( $self, $cr ) = @_;

	my @col = ( $self->{xcol}, $self->{ycol} );
	my $dat = $self->{source}->list;

	my( $xmin, $xmax ) = $self->get_source_bounds(0);
	my( $ymin, $ymax ) = $self->get_view_bounds(1);

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
	my( $self, $cr ) = @_;

	

	# TODO: workaround ->fill gets killed by xserver for unknown reason
	my $dat = $self->{source}->list;
	if( @$dat < 4000 ){
		# TODO: translucent
		# TODO: gradient
		$cr->fill_preserve;
	}

	$cr->set_line_width( $self->{line_width} );
	$cr->stroke;
}


1;
