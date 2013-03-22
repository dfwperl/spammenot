package SpamMeNot::Daemon;

use strict;
use warnings;

use 5.014; # minimum supported version of Perl is 5.14 (solid unicode support)
use utf8;  # otherwise regexes on utf8-encode strings completely fail

our $VERSION = '0.000001';

use Data::UUID;
use LWP::UserAgent;

use lib 'lib';

use SpamMeNot::Common; # import globals and config defaults (like "$TIMEOUT")


sub new
{
   my $self  = bless {}, shift @_;
   my $stdin = \*STDIN;

   $self->{_config}  = {};
   $self->{_session} = {};

   binmode $stdin, ':unix:encoding(UTF-8)';

   $self->_session( stdin => $stdin );
   $self->_config( timeout => $TIMEOUT );

   return $self;
}


sub setup_session
{
   my ( $self, $server ) = @_;

   # per-request UUID
   my $uuid = Data::UUID->new()->to_string( Data::UUID->new()->create() );

   # IP Address of peer
   my $ip = $server->{server}{peeraddr} // '<unknown peer>';

   print <<__BANNER__;
220 Hello $ip - This is a SpamMeNot SMTP server, so we don't be needing viagra
__BANNER__

   # provides ordered warning messages while logging
   my $warn_count = 0;

   # redefine effective warn() call to include a timestamp and the $UUID
   # *this HAS to be in the proces_request() method... don't move it out!
   $SIG{__WARN__} = sub
   {
      # increment warn count
      ++$warn_count;

      # issue the warning; trailing \n prevents verbose line origin BS
      print STDERR qq($uuid [${\ scalar gmtime }] $warn_count: @_);
   };

   # separating banner for each request
   # ... incude the $UUID, the $IP, and a timestamp
   $self->log_incoming_request( $uuid, $ip, scalar gmtime );

   $self->_session( {
      uuid  => $uuid,
      peer  => $ip,
   } );

   return $self;
}


sub _config
{
   my ( $self, $name, $val ) = @_;

   return $self->{_config} unless defined $name;

   if ( ref $name && ref $name eq 'HASH' )
   {
      @{ $self->{_config} }{ keys %$name } = values %$name;
   }
   else
   {
      $self->{_config}->{ $name } = $val
   }

   return $self;
}


sub _session
{
   my ( $self, $name, $val ) = @_;

   return $self->{_session} unless defined $name;

   if ( ref $name && ref $name eq 'HASH' )
   {
      @{ $self->{_session} }{ keys %$name } = values %$name;
   }
   else
   {
      $self->{_session}->{ $name } = $val
   }

   return $self;
}


sub shutdown_session
{
   my $self = shift @_;

   warn 'Session is over.  Everybody go home';

   $self->{_session} = {};
   $self->{_config}  = {};

   return $self;
}


sub log_incoming_request
{
   my ( $self, $uuid, $ip, $when ) = @_;

   print STDERR <<__BANNER__;
\n\n
$uuid #---------------------------------------------------------------
$uuid # New request from $ip at $when
$uuid #---------------------------------------------------------------
__BANNER__
}


sub safe_readline
{
   my $self = shift @_;

   my ( $chars_read, $buffer, $utf8_char );

   # read UTF-8 encoded unicode chars, one at a time, until the end of the line

   while ( $chars_read += read $self->_session->{stdin}, $utf8_char, 1 )
   {
      $buffer .= $utf8_char;

      # $MAX_SAFE_READLINE is exported from SpamMeNot::Common
      say <<__NOT_SAFE__ if $chars_read > $MAX_SAFE_READLINE;
503: Error: Max safe line length exceeded.  Max allowed length is %d.
__NOT_SAFE__

      return $buffer if $utf8_char eq "\n";
   }

   return;
}


sub converse
{
   my ( $self, $input ) = @_;

   push @{ $self->_session->{conversation} }, $input;

   return $self->too_much_chatter
      if @{ $self->_session->{conversation} } > $MAX_CONVERSATION;

   my ( $smtp_command, $smtp_arg ) = split / /, $input, 2;

   $smtp_command = lc $smtp_command;

   if ( !defined $smtp_command || !length $smtp_command )
   {
      $self->_session->{error} = '503 Error: bad syntax';

      return;
   }

   my $params =
   {
      input        => $smtp_arg,
      last_command => $self->_session->{last_command},
      uuid         => $self->_session->{uuid},
      peer         => $self->_session->{peer},
      conversation => $self->_session->{conversation},
   };

   my $response = $self->send_message( http => $smtp_command => $params );

   $self->_session(
      {
         response     => $response,
         last_command => $smtp_command,
      }
   );

   return 1 if $response;

   return;
}

sub write_message_data
{
   my $self = shift @_;

   my $params =
   {
      uuid         => $self->_session->{uuid},
      peer         => $self->_session->{peer},
      write_secret => $self->_session->{write_secret},
      conversation => $self->_session->{conversation},
      last_command => $self->_session->{last_command},
   };

   while ( my $line = $self->safe_readline() )
   {
      $params->{input} = $line;

      my $response = $self->send_message( http => '/_write_data' => $params );

      unless ( $response )
      {
         $self->_session->{error} = '503 Error: internal problem';

         return;
      }

      $self->_session->{end_of_message}++ if $response eq 'end_of_message';

      return 1;
   }
}


sub too_much_chatter
{
   my $self = shift @_;

   $self->_session->{error} =
      '503 Error: too much chatter, just send the damn data OK?';

   return;
}


sub send_message
{
   my ( $self, $scheme, $path, $params ) = @_;

   my $uri = sprintf '%s://%s:%d/%s',
      $scheme,
      $APP_SERVER_HOST,
      $APP_SERVER_PORT,
      $path;

   my $response = LWP::UserAgent->new->post( $uri => $params );

   return $response->content if $response->is_success;

   $self->_session->{error} = $response->status_line;

   $self->_session->{write_secret} = $response->header( 'X-write-secret' )
      if $path eq 'data';

   return;
}


sub end_of_message
{
   my $self = shift @_;

   return $self->_session->{end_of_message};
}


sub response { shift->_session->{response} }


sub ready_for_data
{
   shift->_session->{conversation}->[-1] =~ /$READY_FOR_DATA/
}


sub error { shift->_session->{error} }


1;

__END__


