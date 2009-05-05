package MyChart::Gtk;
use strict;
use warnings;
use Carp;
use Glib qw/ TRUE FALSE /;
use Gtk2;
use MyChart;

# TODO: send "clicked" event per Plot
# TODO: tooltips with user coordinates when hovering over plots
# TODO: range selection (horiz + vertical)

# TODO: zoom to selection
# TODO: provide GtkScrollable Interface.


use Glib::Object::Subclass
	'Gtk2::DrawingArea',
	signals => {
		size_request	=> \&do_size_request,
		expose_event	=> \&do_expose_event,
		configure_event	=> \&do_configure_event,
	},
	properties => [
		Glib::ParamSpec->scalar(
			'chart',
			'MyChart object',
			'reference to MyChart object to use for plotting',
			[qw/ readable writable /]),
	],
;

use constant MIN_GRAPH_WIDTH	=> 150;
use constant MIN_GRAPH_HEIGHT	=> 150;

sub INIT_INSTANCE {
	my $self = shift;

	$self->{chart} = undef;

	# TODO: gtk colors from 'gtk-color-hash'
	# TODO: gtk fonts
	#my $set = $self->get_settings;
	#my $font = $set->get( 'gtk-font-name' );
	#$self->{chart_defaults} = {
	#	title_font	=> $font,
	#	legend_font	=> $font,
	#	# default scale fonts:
	#	label_font	=> $font,
	#	scale_label_font	=> $font,
	#};

	$self->{pixmap} = undef;
	$self->{context} = undef,
	$self->{need_draw} = 1;


        $self->set_events( [qw/
		exposure-mask
		leave-notify-mask
	/]);
}

sub SET_PROPERTY {
	my( $self, $pspec, $newval ) = @_;

	my $n = $pspec->get_name;
	if( $n eq 'chart' ){
		$self->set_chart( $newval );
	} else {
		$self->{$n} = $newval;
	}
}

sub do_size_request {
	my( $self, $req ) = @_;

	# TODO: set min size based on chart layout
	$req->width( MIN_GRAPH_WIDTH );
	$req->height( MIN_GRAPH_HEIGHT );

	shift->signal_chain_from_overridden (@_);
}

sub do_expose_event {
	my( $self, $event ) = @_;

	if( $self->{need_draw} ){
		$self->chart_draw;
	}

	$self->window->draw_drawable( 
		$self->style->fg_gc( $self->state ),
		$self->{pixmap},
		$event->area->x, $event->area->y,
		$event->area->x, $event->area->y,
		$event->area->width, $event->area->height );

	FALSE; # propagate
}

sub do_configure_event {
	my( $self, $event ) = @_;

	my $w = $self->allocation->width;
	my $h = $self->allocation->height;

	$self->{pixmap} = Gtk2::Gdk::Pixmap->new( $self->window, $w, $h, -1 );
	my $cr = $self->{context} = Gtk2::Gdk::Cairo::Context->create( $self->{pixmap} );
	$cr->set_source_rgb( 1,1,1 );
	$cr->paint;

	$self->chart_context;

	TRUE; # stop other
}

sub chart {
	$_[0]{chart};
}

sub set_chart {
	my( $self, $chart ) = @_;

	if( $self->{chart} ){
		$self->{chart}->signal_handler_disconnect(
			$self->{chart_redraw} );
	}

	$self->{chart} = $chart;
	$self->{chart_redraw} = $chart->signal_connect( redraw => sub {
		$self->queue_redraw;
	} );

	$self->chart_context;
}

sub queue_redraw {
	my( $self ) = shift;
	++$self->{need_draw};
	$self->queue_draw;
}

sub chart_context {
	my( $self ) = @_;

	return unless $self->{pixmap};
	my $chart = $self->chart or return;

	my $w = $self->allocation->width;
	my $h = $self->allocation->height;

	$chart->set_context(
		$self->{context},
		$w, $h,
		);

	$self->queue_redraw;
}

sub chart_draw {
	my( $self ) = @_;

	return unless $self->{pixmap};
	my $chart = $self->chart or return;

	$chart->draw;
	$self->{need_draw} = 0;
}

1;
