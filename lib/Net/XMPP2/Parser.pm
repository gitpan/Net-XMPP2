package Net::XMPP2::Parser;
use warnings;
use strict;
# OMFG!!!111 THANK YOU FOR THIS MODULE TO HANDLE THE XMPP INSANITY:
use Net::XMPP2::Node;
use XML::Parser::Expat;

=head1 NAME

Net::XMPP2::Parser - Parser for XML streams (helper for Net::XMPP2)

=head1 SYNOPSIS

   use Net::XMPP2::Parser;
   ...

=head1 DESCRIPTION

This is a XMPP XML parser helper class, which helps me to cope with the XMPP XML.

See also L<Net::XMPP2::Writer> for a discussion of the issues with XML in XMPP.

=head1 METHODS

=over 4

=item B<new>

This creates a new Net::XMPP2::Parser and calls C<init>.

=cut

sub new {
   my $this = shift;
   my $class = ref($this) || $this;
   my $self = {
      stanza_cb => sub { die "No stanza callback provided!" },
      error_cb  => sub { warn "No error callback provided: $_[0]: $_[1]!" },
      stream_cb => sub { },
      @_
   };
   bless $self, $class;
   $self->init;
   $self
}

=item B<set_stanza_cb ($cb)>

Sets the 'XML stanza' callback.

C<$cb> must be a code reference. The first argument to
the callback will be this Net::XMPP2::Parser instance and
the second will be the stanzas root Net::XMPP2::Node as first argument.

If the second argument is undefined the end of the stream has been found.

=cut

sub set_stanza_cb {
   my ($self, $cb) = @_;
   $self->{stanza_cb} = $cb;
}

=item B<set_error_cb ($cb)>

This sets the error callback that will be called when
the parser encounters an syntax error. The first argument
is the exception and the second is the data which caused the error.

=cut

sub set_error_cb {
   my ($self, $cb) = @_;
   $self->{error_cb} = $cb;
}

=item B<set_stream_cb ($cb)>

This method sets the stream tag callback. It is called
when the <stream> tag from the server has been encountered.
The first argument to the callback is the L<Net::XMPP2::Node>
of the opening stream tag.

=cut

sub set_stream_cb {
   my ($self, $cb) = @_;
   $self->{stream_cb} = $cb;
}

=item B<init>

This methods (re)initializes the parser.

=cut

sub init {
   my ($self) = @_;
   $self->{parser} = XML::Parser::ExpatNB->new (
      Namespaces => 1,
      ProtocolEncoding => 'UTF-8'
   );
   $self->{parser}->setHandlers (
      Start => sub { $self->cb_start_tag (@_) },
      End   => sub { $self->cb_end_tag   (@_) },
      Char  => sub { $self->cb_char_data (@_) },
#      CdataStart => sub { $self->cb_cdata_start (@_) },
#      CdataEnd   => sub { $self->cb_cdata_end (@_) },
      Default    => sub { $self->cb_default (@_) },
   );
   $self->{nso} = {};
   $self->{nodestack} = [];
}

=item B<nseq ($namespace, $tagname, $cmptag)>

This method checks whether the C<$cmptag> matches the C<$tagname>
in the C<$namespace>.

C<$cmptag> needs to come from the XML::Parser::Expat as it has
some magic attached that stores the namespace.

=cut

sub nseq {
   my ($self, $ns, $name, $tag) = @_;

   unless (exists $self->{nso}->{$ns}->{$name}) {
      $self->{nso}->{$ns}->{$name} =
         $self->{parser}->generate_ns_name ($name, $ns);
   }

   return $self->{parser}->eq_name ($self->{nso}->{$ns}->{$name}, $tag);
}

=item B<feed ($data)>

This method feeds a chunk of unparsed data to the parser.

=cut

sub feed {
   my ($self, $data) = @_;
   eval {
      $self->{parser}->parse_more ($data);
   };
   if ($@) {
      $self->{error_cb}->($@, $data, 'xml');
   }
}

#=item B<stream_id>
#
#This method retrieves the streams ID attribute.
#
#=cut
#
#sub stream_id {
#   my ($self) = @_;
#   return undef unless $self->{nodestack}->[0];
#   $self->{nodestack}->[0]->attr ('id')
#}

sub cb_start_tag {
   my ($self, $p, $el, %attrs) = @_;
   my $node = Net::XMPP2::Node->new ($p->namespace ($el), $el, \%attrs, $self);
   $node->append_raw ($p->recognized_string);
   if (not @{$self->{nodestack}}) {
      $self->{stream_cb}->($node);
   }
   push @{$self->{nodestack}}, $node;
}

sub cb_char_data {
   my ($self, $p, $str) = @_;
   unless (@{$self->{nodestack}}) {
      warn "characters outside of tag: [$str]!\n";
      return;
   }
   my $node = $self->{nodestack}->[-1];
   $node->add_text ($str);
   $node->append_raw ($p->recognized_string);
}

sub cb_end_tag {
   my ($self, $p, $el) = @_;

   unless (@{$self->{nodestack}}) {
      warn "end tag </$el> read without any starting tag!\n";
      return;
   }

   if (!$p->eq_name ($self->{nodestack}->[-1]->name, $el)) {
      warn "end tag </$el> doesn't match start tags ($self->{tags}->[-1]->[0])!\n";
      return;
   }

   my $node = pop @{$self->{nodestack}};
   $node->append_raw ($p->recognized_string);

   # > 1 because we don't want the stream tag to save all our children...
   if (@{$self->{nodestack}} > 1) {
      $self->{nodestack}->[-1]->add_node ($node);
   }

   eval {
      if (@{$self->{nodestack}} == 1) {
         $self->{stanza_cb}->($self, $node);
      } elsif (@{$self->{nodestack}} == 0) {
         $self->{stanza_cb}->($self, undef);
      }
   };
   if ($@) {
      $self->{error_cb}->($@, undef, 'exception');
   }
}

sub cb_default {
   my ($self, $p, $str) = @_;
   $self->{nodestack}->[-1]->append_raw ($str)
      if @{$self->{nodestack}};
}

=back

=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
