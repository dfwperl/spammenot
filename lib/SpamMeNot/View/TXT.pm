package SpamMeNot::View::TXT;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View';

sub process
{
   my ( $self, $c ) = @_;

   # we always respond with UTF-8 text
   $c->response->header( 'Content-type' => 'text/plain; charset=utf-8' );

   return 1;
}

1;
