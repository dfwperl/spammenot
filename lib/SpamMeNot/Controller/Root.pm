package SpamMeNot::Controller::Root;

use utf8;

use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use Data::Dumper;
use Storable qw( lock_store ); # already used by Catalyst anyway
use Net::IDN::Encode;

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

   chomp $input;

   my $safe_response = sprintf '250 helo %s', $input;

   $c->response->body( $safe_response );
}


sub ehlo :Local
{
   my ( $self, $c ) = @_;

   my $hostname = $c->request->param('input');

   $hostname =~ s/[[:space:]\r\n]+//g;

   my $check_name = Net::IDN::Encode::domain_to_ascii( $hostname );
      $check_name =~ tr/[\.\-]/0/; # the only punctuation allowed in a domainname
      $check_name = ( $check_name ) =~ s/([^[:alnum:]])//g;

   $c->detach
      ( error => [
            sprintf '503 you sent me %d pieces garbage, hippie!', $check_name
         ]
      ) if $check_name;

   $hostname = Net::IDN::Encode::domain_to_ascii( $hostname );

   my $digged = qx(/usr/bin/dig +short a "$hostname") || 'NOTHING';

   ( $digged ) = split /\n/, $digged;

   $c->detach( error => [ '503 Error: your bogus hostname could not be resolved' ] )
      unless $digged;

   $c->response->body( 'EHLO => ' . $digged );

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
