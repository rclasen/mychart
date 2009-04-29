#
# Copyright (c) 2008 Rainer Clasen
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms described in the file LICENSE included in this
# distribution.
#

package MyChart::Source;
use strict;
use warnings;

sub new {
	my( $proto, $a ) = @_;

	$a ||= {};
	my $self = bless { 
		%$a,

		list	=> [],

		min	=> {},
		max	=> {},
		delta	=> {},

	}, ref $proto || $proto;

	$self->set_data( @a{qw/ list min max delta /} ) if $a{list};
	$self;
}

sub set_data {
	my( $self, $list, $min, $max, $delta ) = @_;

	# automagically determin min+max
	if( ! defined $min || !defined $max ){
		foreach my $c ( @$list ){
			foreach my $f ( keys %$c ){
				defined( my $v = $c->{$f} )
					or next;

				if( ! defined $min{$f} || $min{$f} > $v ){
					$min{$f} = $v;
				}

				if( ! defined $max{$f} || $max{$f} < $v ){
					$max{$f} = $v;
				}
			}
		}
	}

	$self->{list} = $list;
	$self->{min} = $min;
	$self->{max} = $max;
	$self->{delta} = $delta || {};
	#TODO: emit signal to flush Scale::bounds and Plot::path
}

sub min {
	my( $self, $col ) = @_;

	$self->{min}{$col};
}

sub max {
	my( $self, $col ) = @_;

	$self->{max}{$col};
}

sub delta {
	my( $self, $col ) = @_;
	$self->{delta}{$col} || 0;
}

sub set_delta {
	my( $self, $col, $delta ) = @_;
	$self->{delta}{$col} = $delta;

	#TODO: emit signal to flush Scale::bounds
}

sub bounds {
	my( $self, $col ) = @_;

	( $self->min($col), $self->max($col), $self->delta($col) );
}

sub list {
	my( $self ) = @_;

	return $self->{list};
}

1;
