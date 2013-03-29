package SpamMeNot::Controller::Root;

use utf8;
use lib 'lib';

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller', 'SpamMeNot::AppUtil'; }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

use Data::Dumper;
use Storable qw( lock_store ); # already used by Catalyst anyway
use Net::IDN::Encode;

=head1 SUPPORTED COMMANDS

   HELO     EHLO     AUTH     RSET     NOOP     HELP
   MAIL     RCPT     DATA     VRFY     QUIT     MOO

=cut

our @supported_commands = qw(
   HELO     EHLO     AUTH     RSET     NOOP     HELP
   MAIL     RCPT     DATA     VRFY     QUIT     MOO
);

# we don't (yet) support things like STARTTLS or PIPELINING or
# else they would be placed in the array variable below

our @extended_commands = qw( NONE );


sub helo :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: you already said HELO' ] )
      if $self->already_sent( $c => 'ehlo' );

   $c->detach( error => [ '503 Error: you already said EHLO' ] )
      if $self->already_sent( $c => 'ehlo' );

   my $input = $self->trim( $c->request->param('input') // '' );

   $input =~ s/[^[:alnum:]\.\-]//g;

   $input = sprintf '250 helo %s', $input;

   $c->response->body( $input );
}


sub ehlo :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: you already said EHLO' ] )
      if $self->already_sent( $c => 'ehlo' );

   $c->detach( error => [ '503 Error: you already said HELO' ] )
      if $self->already_sent( $c => 'helo' );

   my $hostname = $self->trim( $c->request->param('input') // '' );

   $hostname = $self->hostname_valid( $hostname );

   $c->detach( error => [ '503: Error invalid syntax' ] )
      unless $hostname;

   $self->just_sent( $c => 'ehlo' );

   my $mailname = $c->config->{host_mail_name};

   my $response = join "\n", map { '250-' . $_ } $mailname, @extended_commands;

   $c->response->body( $response );
}


sub auth :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: not ready for AUTH' ] )
      unless
         $self->already_sent( $c => 'elho' ) ||
         $self->already_sent( $c => 'helo' );

   $c->detach( error => [ '503 Error: you already said AUTH' ] )
      if $self->already_sent( $c => 'auth' );

   my $input = $self->trim( $c->request->param('input') // '' );

   $self->just_sent( $c => 'auth' );

   $c->response->body( 'AUTH IS A NOOP (for now)' );
}


sub rset :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: no RSET' ] );
}


sub noop :Local
{
   my ( $self, $c ) = @_;

   # this is actually required per RFC.

   $c->response->body( '250 Ok' );
}


sub help :Local
{
   my ( $self, $c ) = @_;

   $c->response->body( '503 Error: see http://tools.ietf.org/html/rfc2821' );
}


sub mail :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: not ready for MAIL' ] )
      unless
         $self->already_sent( $c => 'elho' ) ||
         $self->already_sent( $c => 'helo' );

   $c->detach( error => [ '503 Error: you already said MAIL' ] )
      if $self->already_sent( $c => 'mail' );

   $self->just_sent( $c => 'mail' );

   my $input = $self->trim( $c->request->param('input') // '' );

   $c->response->body( '250 Ok' );
}


sub rcpt :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: not ready for RCPT' ] )
      unless
         $self->already_sent( $c => 'elho' ) ||
         $self->already_sent( $c => 'helo' );

   my $input = $c->request->param('input');

   $c->response->body( '250 Ok' );
}


sub data :Local
{
   my ( $self, $c ) = @_;

   $c->detach( error => [ '503 Error: not ready for DATA' ] )
      unless
      (
         (
            $self->already_sent( $c => 'elho' ) ||
            $self->already_sent( $c => 'helo' )
         )
         && $self->already_sent( $c => qw/ mail rcpt / )
      );

   $c->detach( error => [ '503 You already sent your message' ] )
      if $self->already_sent( $c => 'data' );

   $self->just_sent( $c => 'data' );

   $c->response->body( '354 Send message content; end with <CRLF>.<CRLF>' );
}


sub vrfy :Local
{
   my ( $self, $c ) = @_;

   $c->response->body( '550 Error: sorry, I do not VRFY' );
}


sub moo :Local
{
   my ( $self, $c ) = @_;

   $c->response->body( '200 These are not the droids you\'re looking for.' );
}


sub quit :Local
{
   my ( $self, $c ) = @_;

   $c->delete_session( 'Remote user has QUIT' );

   $c->response->body( '221 Bye' );
}


sub already_sent :Private
{
   my ( $self, $c, @args ) = @_;

   $c->session->{_conversation} //= {};

   for my $arg ( @args )
   {
      return unless $c->session->{_conversation}->{ $arg };
   }

   return 1;
}


sub just_sent :Private
{
   my ( $self, $c, $arg, $val ) = @_;

   $val //= 1;

   $c->session->{_conversation} //= {};

   $c->session->{_conversation}->{ $arg } = $val;

   return $c->session->{_conversation}->{ $arg };
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

   # every request to the Catalyst app from the daemon must include a UUID
   unless ( $c->req->param( 'uuid' ) )
   {
      $c->log->error('Request did not include the mandatory UUID parameter!')
         and $c->detach( 'error' )
   }

   unless ( $c->session->{uuid} )
   {
      $c->session( uuid => $c->request->param('uuid') ) # first session call
         if $c->request->param('uuid')
   }

   unless ( $c->session->{peer} )
   {
      $c->session( peer => $c->request->param('peer') ) # first session call
         if $c->request->param('peer')
   }

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
      $c->detach( error => [ 'You already sent your message.  Please QUIT' ] );
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
   my ( $self, $c ) = @_;

   if ( scalar @{ $c->error } )
   {
      for my $error ( @{ $c->error } )
      {
          $c->log->error( $error );
      }

      $c->response->status( 500 );

      $c->response->body( '500 Error: internal server error (that sucks)' );
   }

   $c->forward( 'TXT' );

   $c->clear_errors;
}


__PACKAGE__->meta->make_immutable;

1;
