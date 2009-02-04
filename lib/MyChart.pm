#!/bin/perl -w
#
# Copyright (c) 2008 Rainer Clasen
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms described in the file LICENSE included in this
# distribution.
#

# TODO: pod
use strict;
use warnings;

package MyChart;
use strict;
use warnings;
use Carp;

# TODO: bargraphs
# TODO: stacked lines + areas
# TODO: pie charts

# TODO: provide "device_to_user" mapping function
# TODO: provide function to check if device_coord is part of graph

our @colors = (
	[1,0,0],	# red
	[0,1,0],	# green
	[0,0,1],	# blue
	[1,1,0],	# yellow
	[1,0,1],	# magenta
	[0,1,1],	# cyan
	#[0,0,0],	# black
);


sub new {
	my( $proto, $a ) = @_;

	bless { 
		context	=> undef,	# cairo context to use
		width	=> undef,	# cairo surface width
		height	=> undef,	# cairo surface hight

		margin_l	=> 0,
		margin_r	=> 0,
		margin_t	=> 0,
		margin_b	=> 0,

		# TODO: translucent
		bg		=> [0.9, 0.9, 0.9],
		chart_bg	=> [1,1,1],	
		axis_fg		=> [0,0,0],
		border_fg	=> [0,0,0],
		plot_box	=> 1,

		title		=> '',
		title_fg	=> [0,0,0],
		title_font	=> 'Sans 8',

		# TODO: legend
		legend		=> undef,	# [l,t,r,b]|'l'|'t'|'r'|'b'
		legend_font	=> 'Sans 8',

		# defaults for plots:
		colors		=> [ @colors ],
		line_style	=> 1,
		line_width	=> 1,


		$a ? %$a : (),

		plot	=> [],		# list of MyChart::Plot objects

		defscale => [
			undef,	# default horizontal scale name
			undef,	# default vertical scale name
		],

		scale	=> {		# scale name => { MyChart::Scale + axis }
		},

		axis	=> [		# "undef" becomes list of scales on axis
			[ # dimension=0 / horizontal
				undef, # position=0 / zero
				undef, # position=1 / bottom
				undef, # position=2 / top
				undef, # position=3 / hidden
			],
			[ # dimension=1 / vertical
				undef, # position=0 / zero
				undef, # position=1 / left
				undef, # position=2 / right
				undef, # position=3 / hidden
			],
		],

		layout	=> undef,	# calculated coordinates

	}, ref $proto || $proto;
}

sub set_context {
	my( $self, $context, $w, $h ) = @_;
	# TODO: flush caches?
	@{$self}{qw/ context width height /} = ( $context, $w, $h );
	$self->{layout} = undef;
}

sub add_scale {
	my $self = shift;

	while( my( $n, $d ) = splice( @_, 0, 2 ) ){
		if( exists $self->{scale}{$n} ){
			croak "scale $n already defined";
		}

		my $dim = exists $d->{horizontal} && $d->{horizontal} ? 0 : 1;

		my $pos;
		if( ! exists $d->{position} ){
			$pos = 1;

		} elsif( ! defined $d->{position} ){
			$pos = 3;
		
		} elsif( $d->{position} > 3 || $d->{position} < 0 ){
			croak "invalid axis position $pos";

		} else {
			$pos = $d->{position};

		}

		$self->{axis}[$dim][$pos] ||= [];

		my $scale = $self->{scale}{$n} = MyChart::Scale->new({
			inside		=> @{$self->{axis}[$dim][$pos]} % 2,
			%$d,
			dimension	=> $dim,
			position	=> $pos,
		});

		$self->{defscale}[$dim] ||= $n;

		push @{$self->{axis}[$dim][$pos]}, $scale;
	}
}

sub get_scale {
	my( $self, $name ) = @_;

	return unless exists $self->{scale}{$name};
	$self->{scale}{$name};
}

sub set_bounds {
	my( $self, $name, $min, $max ) = @_;

	my $scale = $self->get_scale($name)
		or croak "no such scale: $name";
	$scale->set_bounds( $min, $max );
}

sub add_plot {
	my $self = shift;

	while( my( $n, $d ) = splice( @_, 0, 2 ) ){

		# find scales for plot:
		my $xsname = $d->{xscale} || $self->{defscale}[0];
		exists $self->{scale}{$xsname}
			or croak "addplot $n: no such scale: $xsname";

		my $ysname = $d->{yscale} || ( 
			exists $self->{scale}{$n} ? $n : $self->{defscale}[1] );
		exists $self->{scale}{$ysname}
			or croak "addplot $n: no such scale: $ysname";

		my $xscale = $self->{scale}{$xsname};
		my $yscale = $self->{scale}{$ysname};
		$xscale->dimension != $yscale->dimension
			or croak "scales $xsname and $ysname use same dimension";

		# TODO: rotate plot

		my $color = $d->{color} || shift @{$self->{colors}};

		# setup plot
		my $type = $d->{type} || 'Line';
		my $plot = "MyChart::Plot::$type"->new({
			# chart defaults:
			line_type	=> $self->{line_type},
			line_width	=> $self->{line_width},

			# defaults based on user input:
			xcol		=> $xsname,
			ycol		=> $ysname,

			# user parameters
			%$d,

			color	=> $color,
		});
		$xscale->add_plot( $plot );
		$yscale->add_plot( $plot );

		push @{$self->{plot}}, $plot;
	}
}

=pod

+----------------------------------------------------------+
|\  margin t                                              /|
| +------------------------------------------------------+ |
| | title                                                | |
| +------------------------------------------------------+ |
|m|\  legend t                                          /|m|
|a| +--------------------------------------------------+ |a|
|r|l|         # value                  scale           |l|r|
|g|e|          t  |                                    |e|g|
|i|g| ######      |                             ###### |g|i|
|n|e| scale  t +--+-------------------------+ t scale  |e|n|
| |n| value  --+                            |          |n| |
|l|d|          |                            +-- value  |d|r|
| | |          |                            |          | | |
| |l|          +----+-----------------------+          |r| |
| | |               |                                  | | |
| | |          t    |                                  | | |
| | |         #  value                 scale           | | |
| | +--------------------------------------------------+ | |
| |/  legend b                                          \| |
| +------------------------------------------------------+ |
|/  margin b                                              \|
+----------------------------------------------------------+

=cut

sub get_scale_size {
	my( $self, $dim, $pos ) = @_;

	my $s = 0;
	foreach my $scale ( @{$self->{axis}[$dim][$pos]} ){
		next if $scale->inside;
		my $ss = $scale->get_size( $self->{context} );
		#print STDERR ref($self), "::get_scale_size $dim $pos : $ss\n";
		$s = $ss if $ss > $s;
	}
	return $s;
}

sub build_title {
	my( $self ) = @_;

	my $fd = Gtk2::Pango::FontDescription->from_string( $self->{title_font} );
	my $l = Gtk2::Pango::Cairo::create_layout( $self->{context} );
	$l->set_font_description( $fd );
	$l->set_text( $self->{title} );
	$l;
}

sub build_layout {
	my( $self ) = @_;

	my( $cr, $w, $h ) = @{$self}{qw(context width height )};
	my $layout;

	# main box
	$layout->{box} = [
		$self->{margin_l},
		$self->{margin_t},
		$w - $self->{margin_r},
		$h - $self->{margin_b},
	];


	# initial plot size
	my $lplot = $layout->{plot} = [@{$layout->{box}}];


	# title
	if( $self->{title} ){
		$self->{title_layout} ||= $self->build_title;
		my $height = ($self->{title_layout}->get_pixel_size)[1];

		$layout->{title} = [
			$lplot->[0],
			$lplot->[1],
			$lplot->[2],
			$lplot->[1] + $height,
		];
		$lplot->[1] = $layout->{title}[3];
	}


	# legend
	if( $self->{legend} ){
		my $height = 10; # TODO legend size
		my $width = 100; # TODO legend size
	
		if( ref $self->{legend} eq 'ARRAY' 
			&& 4 == @{$self->{legend}} ){

			$layout->{legend} = [
				$self->{legend}[0],
				$self->{legend}[1],
				$self->{legend}[2] 
					|| $self->{legend}[0] + $width,
				$self->{legend}[3]
					|| $self->{legend}[1] + $height,
			];

		} elsif( $self->{legend} eq 't' ){
			$layout->{legend} = [
				$lplot->[0],
				$lplot->[1],
				$lplot->[2],
				$lplot->[1] + $height,
			];
			$lplot->[1] = $layout->{legend}[3];

		} elsif( $self->{legend} eq 't' ){
			$layout->{legend} = [
				$lplot->[0],
				$lplot->[1],
				$lplot->[0] + $width,
				$lplot->[3],
			];
			$lplot->[0] = $layout->{legend}[2];

		} elsif( $self->{legend} eq 'r' ){
			$layout->{legend} = [
				$lplot->[2] - $width,
				$lplot->[1],
				$lplot->[2],
				$lplot->[3],
			];
			$lplot->[2] = $layout->{legend}[0];

		} elsif( $self->{legend} eq 'b' ){
			$layout->{legend} = [
				$lplot->[0],
				$lplot->[3] - $height,
				$lplot->[2],
				$lplot->[3],
			];
			$lplot->[3] = $layout->{legend}[1];

		} else {
			croak "invalid legend placement";
		}
	}

	# scales' size + box line_width + axis line_width
	$layout->{plot} = [
		$lplot->[0] + $self->get_scale_size( 1, 1 ) +2,
		$lplot->[1] + $self->get_scale_size( 0, 2 ) +2,
		$lplot->[2] - $self->get_scale_size( 1, 2 ) -2,
		$lplot->[3] - $self->get_scale_size( 0, 1 ) -2,
	];


	$layout;
}


sub plot {
	my( $self ) = @_;


	# TODO: cache bounds


	# get data bounds
	foreach my $scale ( values %{$self->{scale}} ){
		$scale->get_bounds;
	}
	
	# layout
	my( $cr, $w, $h ) = @{$self}{qw(context width height )};
	my $layout = $self->{layout} ||= $self->build_layout;



	# background
	$cr->rectangle( 0, 0, $w, $h);
	$cr->clip_preserve;
	$cr->set_source_rgb( @{$self->{bg}} );
	$cr->fill;

	# border
	$cr->rectangle( 0.5, 0.5, $w-1, $h-1);
	$cr->set_line_width( 1 );
	$cr->set_source_rgb( @{$self->{border_fg}} );
	$cr->stroke;

	# title
	if( $self->{title} ){
		$cr->set_source_rgb( @{$self->{title_fg}} );
		my( $lw, $lh ) = $self->{title_layout}->get_pixel_size;

		$cr->move_to( 
			($layout->{title}[0] + $layout->{title}[2] - $lw)/2,
			($layout->{title}[1] + $layout->{title}[3] - $lh)/2,
		);
		Gtk2::Pango::Cairo::show_layout( $cr, $self->{title_layout} );
	}

	# TODO: setup axises + scales according
	# TODO: draw legend

	# plot / chart area:  backround
	$cr->rectangle( 
		$layout->{plot}[0],
		$layout->{plot}[1],
		$layout->{plot}[2] - $layout->{plot}[0],
		$layout->{plot}[3] - $layout->{plot}[1] );
	$cr->set_source_rgb( @{$self->{chart_bg}} );
	$cr->fill;

	$cr->set_line_width( 1 );
	$cr->set_source_rgb( @{$self->{axis_fg}} );
	if( $self->{plot_box} ){
		$cr->rectangle( 
			$layout->{plot}[0] -0.5,
			$layout->{plot}[1] -0.5,
			$layout->{plot}[2] - $layout->{plot}[0] + 1,
			$layout->{plot}[3] - $layout->{plot}[1] + 1 );
		$cr->stroke;

	} else {

		# bottom
		if( @{$self->{axis}[0][1]} ){
			$cr->move_to( $layout->{plot}[0] -0.5, $layout->{plot}[3] +0.5 );
			$cr->line_to( $layout->{plot}[2] +0.5, $layout->{plot}[3] +0.5 );
			$cr->stroke;
		}

		# top
		if( @{$self->{axis}[0][2]} ){
			$cr->move_to( $layout->{plot}[0] -0.5, $layout->{plot}[1] -0.5 );
			$cr->line_to( $layout->{plot}[2] +0.5, $layout->{plot}[1] -0.5 );
			$cr->stroke;
		}

		# left
		if( @{$self->{axis}[1][1]} ){
			$cr->move_to( $layout->{plot}[0] -0.5, $layout->{plot}[3] +0.5 );
			$cr->line_to( $layout->{plot}[0] -0.5, $layout->{plot}[1] -0.5 );
			$cr->stroke;
		}

		# right
		if( @{$self->{axis}[1][2]} ){
			$cr->move_to( $layout->{plot}[2] +0.5, $layout->{plot}[3] +0.5 );
			$cr->line_to( $layout->{plot}[2] +0.5, $layout->{plot}[1] -0.5 );
			$cr->stroke;
		}

	}


	# clip to plot region (when zooming / scale bounds < source bounds)
	# and draw plots
	$cr->save;
	$cr->rectangle( 
		$layout->{plot}[0],
		$layout->{plot}[1],
		$layout->{plot}[2] - $layout->{plot}[0],
		$layout->{plot}[3] - $layout->{plot}[1] );
	$cr->clip;

	foreach my $plot ( @{$self->{plot}} ){
		$plot->set_size( 
			$layout->{plot}[0],
			$layout->{plot}[1],
			$layout->{plot}[2] - $layout->{plot}[0],
			$layout->{plot}[3] - $layout->{plot}[1] );
		$plot->plot( $cr );
	}
	$cr->restore;


	# draw scales (tics + tic labels + axis labels)
	foreach my $scale ( values %{$self->{scale}} ){
		$scale->plot( $cr, @{$layout->{plot}} );
	}


}

1;
