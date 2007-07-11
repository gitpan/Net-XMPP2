package DevCL::Browser;
use strict;
use Gtk2;
use POSIX qw/strftime/;
use Gtk2::SimpleList;
use DevCL::TreeView;

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = { @_ };
   bless $self, $class
}

sub start {
   my ($self) = @_;

   $self->{t} = {};

   my $w = Gtk2::Window->new ('toplevel');
   $w->set_default_size (400, 500);
   $w->signal_connect (destroy => $self->{on_destroy});

   my $t = $self->{tree} = DevCL::TreeView->new;
   my $tv = $t->init ("Contact");

   $t->set_activate_cb (sub {
      my ($title, $id, $us) = @_;
      print "ACT $title : $id!\n";
   });

   $w->add ($tv);
   $w->show_all;

   $self->attach;
}

sub attach {
   my ($self) = @_;

   $::CLIENT->reg_cb (
      roster_update =>sub {
      }
   );
}


1
