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
use MyChart::Source;
use MyChart::Scale::Horizontal;
use MyChart::Scale::Vertical;
use MyChart::Plot::Line;
use MyChart::Plot::Area;

# TODO: bargraphs
# TODO: stacked lines + areas
# TODO: pie charts

# TODO: provide "device_to_user" mapping function
# TODO: provide function to check if device_coord is part of graph
# TODO: selections: none, single cursor, range

# TODO: provide GtkScrollable Interface. Draw "full" scale + plot to
# backing store and copy only viewport area to Widget.

# default colors to use for plots:
our @colors = (
	[1,0,0],	# red
	[0,1,0],	# green
	[0,0,1],	# blue
	[1,1,0],	# yellow
	[1,0,1],	# magenta
	[0,1,1],	# cyan
	[0,0,0],	# black
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

		# translucent
		bg		=> [0.9, 0.9, 0.9],
		bg_alpha	=> 1,
		chart_bg	=> [1,1,1],	
		chart_bg_alpha	=> 1,
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
		line_style	=> 0,
		line_width	=> 1,

		# TODO: (more) defaults for scales:
		label_font      => 'Sans 8',
		scale_label_font   => 'Sans 8',

		$a ? %$a : (),

		plot	=> [],		# list of MyChart::Plot objects

		defscale => [
			undef,		# default horizontal scale name
			undef,		# default vertical scale name
		],

		scale	=> {		# scale name => { MyChart::Scale + axis }
		},

		axis	=> [		# "undef" becomes list of scales on axis
			[		# orientation=0 / horizontal
				undef,	# position=0 / zero
				undef,	# position=1 / bottom
				undef,	# position=2 / top
				undef,	# position=3 / hidden
			],
			[		# orientation=1 / vertical
				undef,	# position=0 / zero
				undef,	# position=1 / left
				undef,	# position=2 / right
				undef,	# position=3 / hidden
			],
		],

		layout	=> undef,	# calculated coordinates

	}, ref $proto || $proto;
}

sub set_context {
	my( $self, $context, $w, $h ) = @_;

	@{$self}{qw/ context width height /} = ( $context, $w, $h );

	#print STDERR "MyChart::set_context size: $w, $h\n";
	foreach my $child ( values %{$self->{scale}}, @{$self->{plot}} ){
		$child->set_context( $context );
	}

	# clear caches
	$self->{layout} = undef;
}

sub add_scale {
	my $self = shift;

	while( my( $sname, $d ) = splice( @_, 0, 2 ) ){
		if( exists $self->{scale}{$sname} ){
			croak "scale $sname already defined";
		}

		my $orient;
		if( ! exists $d->{orientation} || ! defined $d->{orientation} ){
			$orient = 1;
			
		} elsif( $d->{orientation} < 0 || $d->{orientation} > 1 ){
			croak "invalid orientation $d->{orientation}";

		} else {
			$orient = $d->{orientation};
		}

		my $pos;
		if( ! exists $d->{position} ){
			$pos = 1;

		} elsif( ! defined $d->{position} ){
			$pos = 3;
		
		} elsif( $d->{position} > 3 || $d->{position} < 0 ){
			croak "invalid axis position $d->{position}";

		} else {
			$pos = $d->{position};

		}

		$self->{axis}[$orient][$pos] ||= [];

		my %a = (
			inside		=> @{$self->{axis}[$orient][$pos]} % 2,
			label_font      => $self->{label_font},
			scale_label_font   => $self->{scale_label_font},

			%$d,

			position	=> $pos,
			context		=> $self->{context},
		);
		my $scale = $self->{scale}{$sname} = $orient == 0 
			? MyChart::Scale::Horizontal->new( \%a )
			: MyChart::Scale::Vertical->new( \%a );

		$self->{defscale}[$orient] ||= $sname;

		push @{$self->{axis}[$orient][$pos]}, $scale;
	}

	# clear caches
	#$self->{bounds} = undef;
	$self->{layout} = undef;
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

	# clear caches
	#$self->{bounds} = undef;
}

sub flush_bounds {
	my( $self, $name ) = @_;

	my $scale = $self->get_scale($name)
		or croak "no such scale: $name";
	$scale->flush_bounds;
}

sub flush_bounds_all {
	my( $self ) = @_;

	foreach my $scale ( values %{ $self->{scale} } ){
		$scale->flush_bounds;
	}
}

sub add_plot {
	my $self = shift;


	foreach my $d ( @_ ){
		#print STDERR "add_plot $d->{ycol} $d->{legend}\n";

		# find scales for plot:
		my $xsname = $d->{xscale} || $d->{xcol} || $self->{defscale}[0];
		exists $self->{scale}{$xsname}
			or croak "addplot: no such scale: $xsname";

		my $ysname = $d->{yscale} || $d->{ycol} || $self->{defscale}[1];
		exists $self->{scale}{$ysname}
			or croak "addplot: no such scale: $ysname";

		#print STDERR "add_plot scales: $xsname, $ysname\n";
		my $xscale = $self->{scale}{$xsname};
		my $yscale = $self->{scale}{$ysname};
		$xscale->orientation != $yscale->orientation
			or croak "scales $xsname and $ysname use same orientation";

		my $rotate = $xscale->orientation != 0;

		my $color = $d->{color} || shift @{$self->{colors}};

		# setup plot
		my $type = $d->{type} || 'Line';

		# TODO: auto-load plot module
		my $plot = "MyChart::Plot::$type"->new({
			# chart defaults:
			line_style	=> $self->{line_style},
			line_width	=> $self->{line_width},

			# defaults based on user input:
			xcol		=> $xsname,
			ycol		=> $ysname,

			# user parameters
			%$d,

			context		=> $self->{context},
			rotate		=> $rotate,
			color		=> $color,
		});
		$xscale->add_plot( $plot );
		$yscale->add_plot( $plot );

		push @{$self->{plot}}, $plot;
	}

	# clear caches
	$self->{layout} = undef;
	#$self->{bounds} = undef;
}

sub get_plot {
	my( $self, $id ) = @_;

	return if $id > $#{$self->{plot}};
	$self->{plot}[$id];
}

sub flush_plot_all {
	my( $self, $name ) = @_;

	foreach my $plot ( @{ $self->{plot} } ){
		$plot->flush;
	}
}


=pod

+----------------------------------------------------------------------+
|\  margin t                                                          /|
| +------------------------------------------------------------------+ |
| | title                                                            | |
| +------------------------------------------------------------------+ |
| |\  legend t                                                      /| |
|m| +--------------------------------------------------------------+ |m|
|a| |    scale2      +         value              -                | |a|
|r|l|                -value                       +       scale1   |l|r|
|g|e|      .      .     |t       |t                  .      .      |e|g|
|i|g|scale2|scale1|     |        |                   |scale1|      |g|i|
|n|e|  +   |  +   |  +--+--------+----------------+  |  +   |  -   |e|n|
| |n|      |value |--+                            |  |      |      |n| |
|l|d|      |      |t |                            +--|value |      |d|r|
| | |      |      |  |                            | t|      |      | | |
| |l|value |      |--+                            +--|      |value |r| |
| | |      |      |t |                            | t|      |      | | |
| | |  -   |  -   |  +----+---------+-------------+  |  -   |  +   | | |
| | |      |      |       |         |                |      |scale2| | |
| | |      .      .       |t        |t               .      .      | | |
| | |    scale1         value                                      | | |
| | |    scale2                   value                            | | |
| | +--------------------------------------------------------------+ | |
| |/  legend b                                                      \| |
| +------------------------------------------------------------------+ |
|/  margin b                                                          \|
+----------------------------------------------------------------------+

=cut

sub max {
	my $m = shift;
	foreach( @_ ){
		if( ! defined($m) || (defined($_) && $_ > $m) ){
			$m = $_;
		}
	}
	$m;
}

sub get_scale_size {
	my( $self, $orient, $pos ) = @_;

	my @s = (0, 0, 0); # "width", "before", "after"
	foreach my $scale ( @{$self->{axis}[$orient][$pos]} ){
		next if $scale->inside;
		my @ss = $scale->get_space;
		#print STDERR ref($self), "::get_scale_size $orient $pos : $ss\n";
		for my $i (0 .. 2){
			$s[$i] = &max( $ss[$i], $s[$i] );
		}
	}
	return @s;
}

sub get_scales_size {
	my( $self ) = @_;

	my @l = $self->get_scale_size( 1, 1 );
	my @t = $self->get_scale_size( 0, 2 );
	my @r = $self->get_scale_size( 1, 2 );
	my @b = $self->get_scale_size( 0, 1 );

	return (
		&max( $l[0], $t[1], $b[1] ),
		&max( $t[0], $l[1], $r[1] ),
		&max( $r[0], $t[2], $b[2] ),
		&max( $b[0], $t[2], $b[2] ),
	);
}

sub build_pango {
	my( $self, $font, $text ) = @_;

	my $fd = Gtk2::Pango::FontDescription->from_string( $font );
	my $l = Gtk2::Pango::Cairo::create_layout( $self->{context} );
	$l->set_font_description( $fd );
	$l->set_text( $text );
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
		$self->{title_layout} ||= $self->build_pango(
			$self->{title_font}, $self->{title} );
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

	# TODO: allocate axis label space
	# TODO: multiple scales, setup area for each, get max tic space

	# scales' size + box line_width + axis line_width
	my $sborder = 2;
	my @ss = $self->get_scales_size;
	$lplot = $layout->{plot} = [
		$lplot->[0] + $ss[0] + $sborder,
		$lplot->[1] + $ss[1] + $sborder,
		$lplot->[2] - $ss[2] - $sborder,
		$lplot->[3] - $ss[3] - $sborder,
	];


	foreach my $child ( values %{$self->{scale}}, @{$self->{plot}} ){
		$child->set_plot_size( $lplot );
	}
	
	$layout;
}

sub draw_bg {
	my( $self ) = @_;

	my $cr = $self->{context};

	$cr->save;
	$cr->set_operator( 'source' );
	$cr->set_source_rgba( @{$self->{bg}}, $self->{bg_alpha} );
	$cr->paint;
	$cr->restore;

}

sub draw_chart_bg {
	my( $self ) = @_;

	my $cr = $self->{context};
	my $layout = $self->{layout};

	$cr->rectangle( 
		$layout->{plot}[0],
		$layout->{plot}[1],
		$layout->{plot}[2] - $layout->{plot}[0],
		$layout->{plot}[3] - $layout->{plot}[1] );

	$cr->set_source_rgba( 
		@{$self->{chart_bg}}, $self->{chart_bg_alpha} );
	$cr->fill;
}

sub draw {
	my( $self ) = @_;


	# get data bounds
	# no caching, needs to be rebuilt on $source or $scale->bounds update
	foreach my $scale ( values %{$self->{scale}} ){
		$scale->get_bounds;
	}
	
	# layout
	my( $cr, $w, $h ) = @{$self}{qw(context width height )};
	my $layout = $self->{layout} ||= $self->build_layout;



	# background
	$cr->rectangle( 0, 0, $w, $h);
	$cr->clip;

	$self->draw_bg;


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

	# plot / chart area:  backround
	$self->draw_chart_bg;



	# draw axises
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
		$plot->draw( $cr );
	}
	$cr->restore;


	# draw scales (tics + tic labels + axis labels)
	foreach my $scale ( values %{$self->{scale}} ){
		$scale->draw;
	}

	# TODO: draw legend

}

1;
