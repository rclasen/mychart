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

	bless { 
		list	=> [],

		min	=> {},
		max	=> {},
		delta	=> {},

		$a ? %$a : (),
	}, ref $proto || $proto;
}

sub set_data {
	my( $self, $list, $min, $max, $delta ) = @_;
	#TODO: automagically determin min+max
	$self->{list} = $list;
	$self->{min} = $min;
	$self->{max} = $max;
	$self->{delta} = $delta || {};
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

	#TODO: emit signal?
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
