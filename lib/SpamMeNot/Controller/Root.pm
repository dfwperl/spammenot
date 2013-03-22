package SpamMeNot::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

use utf8;

use Data::Dumper;
use Time::HiRes ();

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config( namespace => '' );

=head1 NAME

SpamMeNot::Controller::Root - Root Controller for SpamMeNot

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut


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

   # after client sent data, they are only allowed to quit
   if
   (
      $c->session->{called_data} &&
      (
         $c->request->path ne 'quit'       &&
         $c->request->path ne '_write_data'
      )
   )
   {
      $c->detach( error => 'You already sent your message.  Please QUIT.' );
   }

   $c->session->{conversation} //= [];

   $c->detach( error => '503 Error: too much chatter, just send the data OK?' )
      if @{ $c->session->{conversation} } > $c->config->{max_chatter};

   push @{ $c->session->{conversation} }, $c->request->param( 'input' )
      if $c->request->param( 'input' );
}


sub _ready_for_data :Local
{
   my ( $self, $c ) = @_;

   if ( $c->session->{conversation}->[-1] =~ /^DATA\r?\n$/ )
   {
      $c->response->body( 'ready' )
   }
   else
   {
      $c->response->body( 'not ready' )
   }
}


=head1 SUPPORTED COMMANDS

HELO     EHLO     AUTH     RSET     NOOP     HELP
MAIL     RCPT     DATA     VRFY     QUIT     MOO

=cut

sub helo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'HELO => ' . Dumper $c->request->params );
}


sub ehlo :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'EHLO => ' . Dumper $c->request->params );
}


sub auth :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'AUTH IS A NOOP => ' . Dumper $c->request->params );
}


sub rset :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'RSET YOSELF => ' . Dumper $c->request->params );
}


sub noop :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'NOOP => ' . Dumper $c->request->params );
}


sub help :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'HELP => ' . Dumper $c->request->params );
}


sub mail :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'MAIL => ' . Dumper $c->request->params );
}


sub rcpt :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'RCPT => ' . Dumper $c->request->params );
}


sub data :Local
{
   my ( $self, $c ) = @_;

   $c->session( called_data => 1 );

   $c->session( write_secret => join ( '', ( rand Time::HiRes::time ) x 2 ) );

   $c->response->header( 'X-write-secret' => $c->session->{write_secret} );

   $c->response->body( '354 Send message content; end with <CRLF>.<CRLF>' );
}


sub vrfy :Local
{
   my ( $self, $c ) = @_;

   my $input = $c->request->param( 'input' );

   $c->response->body( 'VRFY => ' . Dumper $c->request->params );
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


sub _write_message_data :Local
{
   my ( $self, $c ) = @_;

   my $secret = $c->request->param( 'secret' );

   unless ( $secret eq $c->session->{write_secret} )
   {
      $c->detach( error => '503 Error: unauthorized' );
   }

   my $input_line     = $c->request->param( 'data' );
   my $message_handle = $c->session->{message_handle};

   unless ( fileno $c->session->{message_handle} )
   {
      $c->detach( error => 'message storage unconfigured!' )
         unless $c->config->{message_storage};

      my $message_file =
         $c->config->{message_storage } . '/' .
         $c->request->param( 'uuid' );

      $c->session( message_file => $message_file );

      open $message_handle,
         '>:unix:encoding(UTF-8)',
         $c->config->{mail_storage} . '/' . $message_file
            or $c->log->error( 'Could not write data to message file ' . $! )
               and $c->detach( error => '503 Error: internal failure' );

      $message_handle->autoflush;

      $c->session( message_handle => $message_handle );
   }

   if ( -s $c->session->{message_file} > $c->config->{max_message_size} )
   {
      $c->detach( error => '503 Error: maximum message size exceeded' )
   }

   # flush input line to disk
   print $message_handle $input_line;

   # keep track of the last 3 lines, in order to detect the standard
   # <CRLF>.<CRLF> message termator

   $c->session->{prior_lines} //= [];

   $c->session->{prior_lines} =
      [ ${ $c->session->prior_lines }->[ 0, 1 ], $input_line ];

   # check for end of message
   if ( join '', @{ $c->session->{prior_lines} } eq "\r\n.\r\n" )
   {
      $c->session->{end_of_message}++;

      $c->response->body( 'end of message' );
   }
   else
   {
      $c->response->body( 'continue' );
   }
}


sub _end_of_message :Local
{
   my ( $self, $c ) = @_;

   return $c->session->{end_of_message};
}


sub error :Private
{
   my ( $self, $c, $error_message ) = @_;

   if ( $error_message )
   {
      $c->response->body( $error_message );
   }
   else
   {
      $c->response->body( '503 Error: Something went wrong' );
   }

   $c->response->status( 503 );

   $c->delete_session();

}


=head2 default

Standard 404 error page

=cut

sub default :Path
{
   my ( $self, $c ) = @_;

   $c->response->body( '503 Error: command not recognized' );

   $c->response->status( 503 );

   $c->delete_session();
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

superman,,,

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
