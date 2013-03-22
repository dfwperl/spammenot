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
use Storable qw( lock_retrieve );

use lib 'lib';

use SpamMeNot::Common; # import globals and config defaults (like "$TIMEOUT")


sub new
{
   my $class = shift @_;
   my $self  = bless {}, $class;

   $self->{session} = {};

   # per-request UUID
   my $uuid = Data::UUID->new()->to_string( Data::UUID->new()->create() );

   my $session_env = { uuid => $uuid }; # each session has a unique identifier

   my $config_file = $self->send_message( http => _get_config => $session_env );

   my $config;

   eval { $config = lock_retrieve $config_file } or warn $@ and return;

   unlink $config_file;

   $session_env->{config} = $config;

   $self->session( $session_env );

   my $stdin = \*STDIN;

   binmode $stdin, ':unix:encoding(UTF-8)';

   $self->session( {
      stdin   => $stdin,
      timeout => $config->{timeout} || $TIMEOUT,
      cookies => '/dev/shm/' . $uuid, # you should be running this app on linux
   } );

   return $self;
}


sub start_session
{
   my ( $self, $ip ) = @_;

   $self->session( peer => $ip );

   print <<__BANNER__;
220 Hello $ip - This is a SpamMeNot SMTP server, so we won't be needing viagra
__BANNER__

   # provides ordered warning messages while logging
   my $warn_count = 0;
   my $uuid = $self->session->{uuid};

   # redefine effective warn() call to include a timestamp and the $UUID
   # *this HAS to be in the proces_request() method... don't move it out!

   $SIG{__WARN__} = sub
   {
      # increment warn count
      ++$warn_count;

      # issue the warning; trailing \n prevents verbose line origin BS
      print STDERR qq($uuid [${\ scalar gmtime }] $warn_count: @_);
   };

   $self->log_incoming_request( $uuid, $ip, scalar gmtime );

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

   # separating banner for each request in the log
   # ... incude the $UUID, the $IP, and a timestamp

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

      warn "BUFFER! => $buffer" and return $buffer if $utf8_char eq "\n";
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

   # Sadly this can't be pushed upstream to catalyst without a lot of TCP IO,
   # all in memory.  Sending it line by line would be insane too, and since
   # you can't preserve open filehandles inside a catalyst session, you would
   # have to open and close the spool file for every line.  If you can find
   # a way to send this logic upstream to catalyst, please do.  All we can
   # do now is send catalyst the spoolfile, because I'm too afraid to send it a
   # potentially huge message in RAM.

   $self->session( prior_lines => ['','',''] );

   my $message_spool =
      $self->session->{config}->{mail_storage } . '/' .
      $self->session->{uuid} . '.spool';

   $self->session( spool => $message_spool );

   open my $message_handle, '>:unix:encoding(UTF-8)', $message_spool
      or warn( 'Could not write data to spool file ' . $! )
         and $self->session( error => '503 Error: internal failure' )
            and return;

   $message_handle->autoflush;

   MESSAGE_READ: while ( my $line = $self->safe_readline() )
   {

      # keep track of the last 3 lines, in order to detect the standard
      # <CRLF>.<CRLF> message termator

      $self->session(
         prior_lines => [ @{ $self->session->{prior_lines } }[ 1, 2 ], $line ]
      );

      use Data::Dumper;
      warn Dumper $self->session->{prior_lines};

      # flush input line to disk
      print $message_handle $line;

      if ( -s $message_spool > $self->session->{config}->{max_message_size} )
      {
         close $message_handle;

         unlink $message_spool;

         $self->session( error => '503 Error: maximum message size exceeded' );

         return;
      }

      # check for end of message
      if ( join( '', @{ $self->session->{prior_lines} } ) =~ m{\r?\n\.\r?\n} )
      {
         $self->session( end_of_message => 1 );

         last MESSAGE_READ;
      }
   }

   my $params =
   {
      uuid  => $self->session->{uuid},
      peer  => $self->session->{peer},
      spool => $message_spool,
   };

   my $response = $self->send_message( http => _save_message => $params );

   $self->session( {
      data_was_sent  => 1,
      data_was_saved => 1,
      ready_for_data => 0,
   } );

   $self->session( error => '503 Error: internal problem' )
      and return
         unless $response;

   $self->session( response => $response );

   return 1;
}


sub send_message
{
   my ( $self, $scheme, $path, $params ) = @_;

   my $uri = sprintf '%s://%s:%d/%s',
      $scheme, $APP_SERVER_HOST, $APP_SERVER_PORT, $path;

   my $ua = $self->session->{ua} || LWP::UserAgent->new();

   my $cookie_jar = HTTP::Cookies->new( file => $self->session->{cookies} );

   # we can re-use the user agent, but not the cookies object, which sux
   $ua->cookie_jar( $cookie_jar );

   # allows us to re-use the user agent (an optimization)
   $self->session( ua => $ua );

   my $response = $ua->post( $uri => $params );

   $cookie_jar->save();

   chomp $path;

   $self->session( ready_for_data => 1 ) if $path eq 'data';

   return $response->content if $response->is_success;

   $self->session( error => $response->status_line );

   return;
}


sub ready_for_data { shift->session->{ready_for_data} }


sub end_of_message { shift->session->{end_of_message} }


sub response { shift->session->{response} }


sub error { shift->session->{error} }


sub DESTROY {

   my $self = shift @_;

   {
      no warnings;

      eval
      {
         unlink $self->session->{cookies};
         unlink $self->{session}->{spool};
      };
   }

   delete $self->{session};
}

1;

__END__

