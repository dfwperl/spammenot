package SpamMeNot::Daemon;

# this module should be simple; push as much logic upstream to the catalyst
# application as is possible.  The point of the daemon is to be a safe and
# highly-available pass-through to the catalyst app.
#
# The above stated goals have to be balanced with the needs for security,
# encapsulation from the main namespace of the daemon, and i18n.

use strict;
use warnings;

use 5.014; # minimum supported version of Perl is 5.14 (solid unicode support)
use utf8;  # otherwise regexes on utf8-encode strings completely fail

our $VERSION = '0.000001';

use Data::UUID;
use LWP::UserAgent;
use HTTP::Cookies;

use lib 'lib';

use SpamMeNot::Common; # import globals and config defaults (like "$TIMEOUT")


sub new
{
   # STDIN has to be carefully managed; that's the primary reason for new()

   my $self  = bless {}, shift @_;
   my $stdin = \*STDIN;

   binmode $stdin, ':unix:encoding(UTF-8)';

   $self->{session} = {};

   $self->session( { stdin => $stdin, timeout => $TIMEOUT } );

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
220 Hello $ip - This is a SpamMeNot SMTP server, so we won't be needing viagra
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

   $self->session( {
      uuid    => $uuid,               # each session has a unique identifier
      peer    => $ip,                 # pass the client IP through
      cookies => '/dev/shm/' . $uuid, # you should be running this app on linux
   } );

   return $self;
}


sub session
{
   my ( $self, $name, $val ) = @_;

   return $self->{session} unless defined $name;

   if ( ref $name && ref $name eq 'HASH' )
   {
      @{ $self->{session} }{ keys %$name } = values %$name;
   }
   else
   {
      $self->{session}->{ $name } = $val
   }

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

   while ( $chars_read += read $self->session->{stdin}, $utf8_char, 1 )
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

   return $self->write_message_data() if $self->ready_for_data;

   my ( $smtp_command, $smtp_arg ) = split / /, $input, 2;

   $smtp_command = lc $smtp_command;

   my $params =
   {
      input => $smtp_arg,
      uuid  => $self->session->{uuid},
      peer  => $self->session->{peer},
   };

   my $response = $self->send_message( http => $smtp_command => $params );

   $self->session( response => $response );

   return 1 if $response;

   return;
}


sub write_message_data
{
   my $self = shift @_;

   my $params =
   {
      uuid   => $self->session->{uuid},
      peer   => $self->session->{peer},
      secret => $self->session->{secret},
   };

   while ( my $line = $self->safe_readline() )
   {
      $params->{data} = $line;

      my $response = $self->send_message
         (
            http => '/_write_message_data' => $params
         );

      unless ( $response )
      {
         $self->session( error => '503 Error: internal problem' );

         return;
      }

      $self->session( end_of_message => 1 ) if $response eq 'end of message';

      return 1;
   }
}


sub send_message
{
   my ( $self, $scheme, $path, $params ) = @_;

   my $uri = sprintf '%s://%s:%d/%s',
      $scheme, $APP_SERVER_HOST, $APP_SERVER_PORT, $path;

   my $ua = $self->session->{ua} || LWP::UserAgent->new();

   # we can re-use the user agent, but not the cookies object, which sux
   $ua->cookie_jar(
      HTTP::Cookies->new( file => $self->session->{cookies}, autosave => 1 )
   );

   # allows us to re-use the user agent (an optimization)
   $self->session( ua => $ua );

   my $response = $ua->post( $uri => $params );

   return $response->content if $response->is_success;

   $self->session( error => $response->status_line );

   $self->session( secret => $response->header( 'X-Write-Secret' ) )
      if $path eq 'data';

   return;
}


sub end_of_message { shift->session->{end_of_message} }


sub response { shift->session->{response} }


sub ready_for_data
{
   my $self = shift @_;

   return 1
      if $self->session->{ready_for_data} &&
         $self->session->{ready_for_data} eq 'ready';

   $self->session(
      ready_for_data => $self->send_message( http => _ready_for_data => {} )
   );

   return $self->session->{ready_for_data} eq 'ready';
}


sub error { shift->session->{error} }


sub DESTROY {

   my $self = shift @_;

   eval { unlink $self->session->{cookies} };

   delete $self->{session};
}

1;

__END__

