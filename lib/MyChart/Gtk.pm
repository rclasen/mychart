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
# TODO: show/hide individual plots

use Glib::Object::Subclass
	'Gtk2::DrawingArea',
	signals => {
		size_request	=> \&do_size_request,
		expose_event	=> \&do_expose_event,
		configure_event	=> \&do_configure_event,
	},
#	properties => [ # TODO
#	],
;

use constant MIN_GRAPH_WIDTH	=> 150;
use constant MIN_GRAPH_HEIGHT	=> 150;

sub INIT_INSTANCE {
	my $self = shift;

	$self->{chart} = undef;
	$self->{chart_class} = 'MyChart';

	# TODO: gtk colors from 'gtk-color-hash'
	my $set = $self->get_settings;
	my $font = $set->get( 'gtk-font-name' );
	$self->{chart_defaults} = {
		title_font	=> $font,
		legend_font	=> $font,
		# default scale fonts:
		label_font	=> $font,
		scale_label_font	=> $font,
	};

	$self->{pixmap} = undef;
	$self->{need_draw} = 1;


        $self->set_events( [qw/
		exposure-mask
		leave-notify-mask
	/]);
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

	$self->{pixmap} = Gtk2::Gdk::Pixmap->new( $self->window,
		$w, $h, -1 );

	$self->chart->set_context(
		Gtk2::Gdk::Cairo::Context->create( $self->{pixmap} ),
		$w, $h,
		);

	$self->queue_redraw;

	TRUE; # stop other
}

sub queue_redraw {
	my( $self ) = shift;
	++$self->{need_draw};
	$self->queue_draw;
}

sub chart_init {
	my $self = shift;

	"$self->{chart_class}"->new( $self->{chart_defaults} );
}

sub chart_draw {
	my( $self ) = @_;

	return unless $self->{pixmap};
	$self->chart->draw;
	$self->{need_draw} = 0;
}

sub chart {
	my( $self ) = @_;

	$self->{chart} ||= $self->chart_init;
}

sub add_scale {
	my $self = shift;

	$self->chart->add_scale( @_ );
	$self->queue_redraw;
}

sub get_scale {
	my $self = shift;

	$self->chart->get_scale( @_ );
}

sub add_plot {
	my $self = shift;

	$self->chart->add_plot( @_ );
	$self->queue_redraw;
}

sub get_plot {
	my $self = shift;

	$self->chart->get_plot( @_ );
}

sub set_bounds {
	my( $self, $name, $min, $max ) = @_;

	$self->chart->set_bounds( $name, $min, $max );
	$self->queue_redraw;
}


1;
