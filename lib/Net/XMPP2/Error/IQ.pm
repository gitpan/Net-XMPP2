package Net::XMPP2::Error::IQ;
use strict;
no warnings;
use Net::XMPP2::Error::Stanza;
our @ISA = qw/Net::XMPP2::Error::Stanza/;

=head1 NAME

Net::XMPP2::Error::IQ - IQ errors

Subclass of L<Net::XMPP2::Error::Stanza>

=cut

sub init {
   my ($self) = @_;
   my $node = $self->xml_node;

   unless (defined $node) {
      $self->{error_cond} = 'client-timeout';
      $self->{error_type} = 'cancel';
      return;
   }

   $self->SUPER::init;
}

=head2 METHODS

=over 4

=item B<condition ()>

Same as L<Net::XMPP2::Error::Stanza> except that
in case of a IQ timeout it returns:

   'client-timeout'

=cut

sub string {
   my ($self) = @_;

   sprintf "iq error: %s/%s (type %s): %s",
      $self->code || '',
      $self->condition || '',
      $self->type,
      $self->text
}

=back

=cut


=head1 AUTHOR

Robin Redeker, C<< <elmex at ta-sa.org> >>, JID: C<< <elmex at jabber.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2007 Robin Redeker, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Net::XMPP2
