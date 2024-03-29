package Net::XMPP2::Ext::Pubsub;
use strict;
use Net::XMPP2::Util qw/simxml/;
use Net::XMPP2::Namespaces qw/xmpp_ns/;
use Net::XMPP2::Ext;

our @ISA = qw/Net::XMPP2::Ext/;

=head1 NAME

Net::XMPP2::Ext::Pubsub - Implements XEP-0060: Publish-Subscribe

=head1 SYNOPSIS

   my $con = Net::XMPP2::Connection->new (...);
   $con->add_extension (my $ps = Net::XMPP2::Ext::Pubsub->new);
   ...

=head1 DESCRIPTION

This module implements all tasks of handling the publish subscribe
mechanism. (partially implemented)

=cut

sub handle_incoming_pubsub_event {
   my ($self, $node) = @_;
   my (@items);
   if(my ($q) = $node->find_all ([qw/pubsub_ev items/]))
   {
      foreach($q->find_all ([qw/pubsub_ev item/]))
      {
         push(@items, $_);
      }
   }
   $self->event(pubsub_recv => @items);
}

=head1 METHODS

=over 4

=item B<new>

This is the constructor for a pubsub object.
It takes no further arguments.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = bless { @_ }, $class;
   $self->init;
   $self
}

sub init {
   my ($self) = @_;

   $self->reg_cb (
      ext_before_message_xml => sub {
         my ($self, $con, $node) = @_;

         my $handled = 0;
         for ($node->find_all ([qw/pubsub_ev event/])) {
            $self->stop_event;
            $self->handle_incoming_pubsub_event($_);
         }

         $handled
      }
   );
}

=item B<delete_node($con, $node, $cb)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$cb> is the callback

Try to remove a node.

=cut

sub delete_node {
   my ($self, $con, $node, $cb) = @_;

   $con->send_iq (
      set => sub {
         my ($w) = @_;
         simxml ($w, defns => 'pubsub_own', node => {
            name => 'pubsub', childs => [
               { name => 'delete', attrs => [ node => $node ] },
            ]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=item B<create_node ($con, $node, $cb)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$cb> is the callback

Try to create a node.

=cut

sub create_node {
   my ($self, $con, $node, $cb) = @_;

   $con->send_iq (
      set => sub {
         my ($w) = @_;
         simxml ($w, defns => 'pubsub', node => {
            name => 'pubsub', childs => [
               { name => 'create', attrs => [ node => $node ] },
               { name => 'configure', childs => [
                  { name => 'x', attrs => [ xmlns => 'jabber:x:data', type => 'submit' ],
                    childs => [
                       { name => 'field', attrs => [ var => 'FORM_TYPE',
                                                     type => 'hidden'],
                                          childs => [
                          { name => 'value', childs => ['http://jabber.org/protocol/pubsub#node_config']}]
                       },
                       { name => 'field', attrs => [ var => 'pubsub#access_model'],
                                          childs => [
                          { name => 'value', childs => [ 'open'] }]
                       }]
                  }]
               }]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=item B<subscribe_node($con, $node, $cb)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$cb> is the callback

Try to retrieve items.

=cut

sub subscribe_node {
   my ($self, $con, $node, $cb) = @_;
   our $jid = $con->jid;

   $con->send_iq (
      set => sub {
         my ($w) = @_;
         simxml ($w, defns => 'pubsub', node => {
            name => 'pubsub', childs => [
               { name => 'subscribe', attrs => [ 
                  node => $node,
                  jid => $jid ]
               }
            ]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=item B<publish_item($con, $node, $create_cb, $bc)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$create_cb> is the callback
C<$cb> is the callback

Try to publish an item.

=cut

sub publish_item {
   my ($self, $con, $node, $create_cb, $cb) = @_;

   $con->send_iq (
      set => sub {
         my ($w) = @_;
         simxml ($w, defns => 'pubsub', node => {
            name => 'pubsub', childs => [
               { name => 'publish', attrs => [ node => $node ], childs => [
                   { name => 'item', childs => [ $create_cb ] }
                 ]
               },
            ]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=item B<retrive_items($con, $node, $cb)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$cb> is the callback

Try to retrieve items.

=cut

sub retrieve_items {
   my ($self, $con, $node, $cb) = @_;

   $con->send_iq (
      get => sub {
         my ($w) = @_;
         simxml ($w, defns => 'pubsub', node => {
            name => 'pubsub', childs => [
               { name => 'items', attrs => [ node => $node ] }
            ]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=item B<retrive_item($con, $node, $id, $cb)>
C<$con> is the connection already established,
C<$node> is the name of the node to be created
C<$id> is the id of the entry to be retrieved
C<$cb> is the cb

Try to retrieve item.

=cut

sub retrieve_item {
   my ($self, $con, $node, $id, $cb) = @_;

   $con->send_iq (
      get => sub {
         my ($w) = @_;
         simxml( $w, defns => 'pubsub', node => {
            name => 'pubsub', childs => [
               { name => 'items', attrs => [ node => $node ],
                                  childs => [
                  { name => 'item', attrs => [ id => $id ] }]
               }
            ]
         });
      },
      sub {
         my ($node, $err) = @_;
         $cb->(defined $err ? $err : ()) if $cb;
      }
   );
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 CONTRIBUTORS

Chris Miceli - additional work on the pubsub extension

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2::Ext::Pubsub

