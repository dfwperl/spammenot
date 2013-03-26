package SpamMeNot::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use utf8;

use Data::Dumper;
use Storable qw( lock_store );

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

=head1 SUPPORTED COMMANDS

HELO     EHLO     AUTH     RSET     NOOP     HELP
MAIL     RCPT     DATA     VRFY     QUIT     MOO

=cut


sub helo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'HELO => ' . Dumper $c->session );
}


sub ehlo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'EHLO => ' . Dumper $c->session );
}


sub auth :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'AUTH IS A NOOP => ' . Dumper $c->session );
}


sub rset :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'RSET YOSELF => ' . Dumper $c->session );
}


sub noop :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'NOOP => ' . Dumper $c->session );
}


sub help :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'HELP => ' . Dumper $c->session );
}


sub mail :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'MAIL => ' . Dumper $c->session );
}


sub rcpt :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param('input');

   $c->response->body( 'RCPT => ' . Dumper $c->session );
}


sub data :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 You already sent your message' ] )
      if $c->session->{data_was_sent};

   $c->session( ready_for_data => 1 );

   $c->response->body( '354 Send message content; end with <CRLF>.<CRLF>' );
}


sub vrfy :Local
{
   my ( $self, $c ) = @_;

   $c->response->body( '550: Sorry buddy, we do not VRFY' );
}


sub moo :Local
{
   my ( $self, $c ) = @_;

   $c->response->body( 'These are not the droids you\'re looking for.' );
}


sub quit :Local
{
   my ( $self, $c ) = @_;

   $c->delete_session();

   $c->response->body( '221 Bye' );
}


sub _save_message :Local
{
   my ( $self, $c ) = @_;

   $c->session( data_was_sent => 1 );

   my $message_spool = $c->request->param('spool');

   $c->log->error( 'mail spool not sent!' )
      and $c->detach( 'error' )
         unless $c->request->param('spool');

   $c->log->error( 'mail_storage config variable not set!' )
      and $c->detach( 'error' )
         unless $c->config->{mail_storage};

   my $message_file =
      $c->config->{mail_storage } . '/' .
      $c->request->param('uuid');

   rename $message_spool, $message_file
      or $c->log->error( 'could not rename spool file!' )
         and $c->detach( 'error' );

   $c->session( data_was_saved => 1, ready_for_data => 0 );

   $c->response->body( '250 OK, message accepted for delivery' );
}


sub error :Private
{
   my ( $self, $c, $error_message ) = @_;

   if ( $error_message )
   {
      $c->log->error( $error_message );

      $c->response->body( $error_message );
   }
   else
   {
      $c->log->error( 'Something went wrong.  $c->detach("error") was called' );

      $c->response->body( '503 Error: Something went wrong' );
   }

   $c->response->status( 503 );

   $c->delete_session( 'Forcefully terminating session due to error' );
}


sub index :Path :Args(0)
{
   my ( $self, $c ) = @_;

   $c->detach( 'default' );
}


sub begin :Private
{
   my ( $self, $c ) = @_;

   # we always respond with UTF-8 text
   $c->response->header( 'Content-type' => 'text/plain; charset=utf-8' );

   # every request to the Catalyst app from the daemon must include a UUID
   $c->log->error('Request did not include the mandatory UUID parameter!')
      and $c->detach( 'error' )
         unless $c->request->param('uuid');

   $c->session( uuid => $c->request->param('uuid') ) # the first session call
      unless $c->session->{uuid};

   $c->log->error('Session ID mismatch!')
      and $c->detach('error')
         if $c->session->{uuid} ne $c->request->param('uuid');

   # after client sent data, they are only allowed to quit, and we are only
   # allowed to call semi-private "_methods()" (methods with leading "_" prefix)
   if
   (
      $c->session->{end_of_message}  &&
      (
         $c->request->path ne 'quit' &&
         $c->request->path !~ /^_/
      )
   )
   {
      $c->detach( error => 'You already sent your message.  Please QUIT.' );
   }

   $c->session->{conversation} //= [];

   $c->detach( error => '503 Error: too much chatter, just send the data OK?' )
      if @{ $c->session->{conversation} } > $c->config->{max_chatter};

   unless ( $c->session->{ready_for_data} )
   {
      push @{ $c->session->{conversation} },
         $c->request->path . ' ' . ( $c->request->param('input') || '' );
   }
}


sub _get_config :Local
{
   my ( $self, $c ) = @_;

   my $config_store = '/dev/shm/' . $c->session->{uuid} . '.conf';

   my $config = {};

   for my $key ( %{ $c->config } )
   {
      $config->{ $key } = $c->config->{ $key }
         unless ref $c->config->{ $key };
   }

   eval { lock_store $config, $config_store }
      or $c->log->error( 'failed to save session configuration file! ' . $@ )
         and $c->detach( 'error' );

   $c->response->body( $config_store );
}


sub default :Path
{
   # where unsupported SMTP commands come to die

   my ( $self, $c ) = @_;

   $c->response->body( '503 Error: command not recognized' );

   $c->response->status( 503 );

   $c->delete_session( 'Forcefully terminating session due to bad command' );
}


sub end : ActionClass('RenderView')
{
   return;

   my ( $self, $c ) = @_;

   $c->log->warn( Dumper $c->session );
}


__PACKAGE__->meta->make_immutable;

1;
