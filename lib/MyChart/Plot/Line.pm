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
	#$self->{line_style}	||= 0; # TODO
	#$self->{skip_undef}	||= 0; # TODO

	$self;
}

sub build_path {
	my( $self, $cr ) = @_;

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
	my( $self, $cr ) = @_;
	$cr->set_line_width( $self->{line_width} );
	# $cr->set_dash( $foo ) if $self->{line_style}; # TODO
	$cr->set_line_join( 'round' );
	$cr->stroke;
}

1;
