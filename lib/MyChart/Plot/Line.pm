#
# Copyright (c) 2008 Rainer Clasen
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms described in the file LICENSE included in this
# distribution.
#

package MyChart::Plot::Line;
use base 'MyChart::Plot';
use strict;
use warnings;

sub new {
	my( $proto, $a ) = @_;

	my $self = $proto->SUPER::new( $a );

	# config
	$self->{line_width}	||= 1;
	$self->{line_style}	||= 0;	# 0=solid, 1=dashed, 2=dotted, 3=dot-dash
	$self->{line_style}	%= 4; 
	#$self->{skip_undef}	||= 0; # TODO

	$self;
}

sub build_path_loh {
	my( $self ) = @_;

	my $cr = $self->{context};
	my @col = ( $self->{xcol}, $self->{ycol} );
	my $dat = $self->{source}->list;

	my $init = 0;

	foreach( @$dat ){
		my @val = @{$_}{@col};
		next unless defined $val[0] and defined $val[1];

		if( ! $init ){
			$cr->move_to( @val );
			++$init;
		} else {
			$cr->line_to( @val );
		}
	}

	$cr->copy_path;
}

sub do_plot {
	my( $self ) = @_;

	my $cr = $self->{context};

	# TODO: take line_width into account for pattern
	if( $self->{line_style} == 3 ){
		$cr->set_dash( 0, 4, 2, 2, 2 );

	} elsif( $self->{line_style} == 2 ){
		$cr->set_dash( 0, 6, 3 );

	} elsif( $self->{line_style} == 1 ){
		$cr->set_dash( 0, 0, 3 );

	}
	
	$cr->set_line_width( $self->{line_width} );
	$cr->set_line_join( 'round' );
	$cr->set_line_cap( 'round' );
	$cr->set_source_rgb( @{$self->{color}} );
	$cr->stroke;
}

1;
