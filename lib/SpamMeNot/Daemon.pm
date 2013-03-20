package SpamMeNot::Daemon;

use strict;
use warnings;

use 5.014;
use utf8;

our $VERSION = '0.000001';

use HTTP::Request;

use lib 'lib';

use SpamMeNot;
use SpamMeNot::Common;


sub new
{
   my $self = bless {}, shift @_;

   # instantiate the SpamMeNot application which is also a catalyst object
   $self->{c} = SpamMeNot->new();

   my $stdin = \*STDIN;

   binmode $stdin, ':unix:encoding(UTF-8)';

   $self->c->stash( stdin => $stdin );

   return $self;
}


sub c { shift->{c} }


sub setup_session
{
   my $self = shift @_;

   # per-request UUID
   my $uuid = Data::UUID->new()->to_string( Data::UUID->new()->create() );

   # IP Address of peer
   my $ip = $self->{server}{peeraddr} // '<unknown peer>';

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

   $self->c->delete_session( 'making room for next session - clean slate' );

   $self->c->session( {
      uuid  => $uuid,
      peer  => $ip,
   } );
}


sub shutdown_session
{
   my $self = shift @_;

   warn 'Session is over.  Everybody go home';

   $self->c->delete_session();
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

   SAFE_READ: while ( $chars_read += read $self->c->stash->{stdin}, $utf8_char, 1 )
   {
      $buffer .= $utf8_char;

      die <<__NOT_SAFE__ if $chars_read > $MAX_SAFE_READLINE;
ERROR: Max safe line length exceeded.  Max allowed length is %d.
   ...(text: %s)
__NOT_SAFE__

      return $buffer if $utf8_char eq "\n";
   }

   return;
}


sub converse
{
   my $self = shift @_;

   my $params = [ LINE => shift @{ $self->c->stash->{conversation} } ];

   use Data::Dumper;
   say Dumper $self->sendmsg( '/' => $params )
}


sub end_of_message
{
   my $self = shift @_;

   $self->{dummy_value}++;

   return $self->{dummy_value} > 1;
}


sub stash_content
{
   my ( $self, $file_handle ) = shift @_;

   my ( $chars_read, $buffer, $content ) = ( 0, '', '' );

   my $offset = $self->c->stash->{body_offset};

   die "Bad call to stash_content() -- need filehandle seek position\n"
      unless $offset;

   seek $file_handle, $offset, 0;

   # protect ourselves from DOS attacks based on huge messages
   $chars_read = read $file_handle, $buffer, $MAX_MESSAGE_SIZE;

   if ( $chars_read = read $file_handle, $buffer, 1 )
   {
      undef $content;

      warn "503 Error: Sorry, that mail message is too big\n";

      print STDOUT "503 Error: Sorry, that mail message is too big\n";

      return;
   }

   $self->c->stash( mail_content => $content );

   return 1;
}

# XXX this is largely unused right now; it was a proof-of-concept that is
# XXX goign to be removed soon
sub read_headers
{
   warn 'read_headers() called';

   my ( $self, $file_handle, $offset ) = @_;

   my ( $headers, $chars_read, $buffer, $char,
        $current_header, $is_last_header );

   $is_last_header = 0;
   $offset       //= 0;
   $headers        = {};
   $chars_read     = 0;

   binmode $file_handle, ':unix:encoding(UTF-8)';

   warn "going to try to get a header from file handle";

   seek $file_handle, 0, 0;

   # protect ourselves from DOS attacks based on huge messages
   HEAD_READ: while ( $chars_read += read $file_handle, $char, 1 )
   {
      $offset += $chars_read;
      $buffer .= $char;

      {
         use bytes;

         if ( length $buffer > $MAX_HEADER_LENGTH )
         {
            warn "503 Error: Sorry, that mail header is too big (@{[ length $buffer ]} bytes) ($buffer)\n";

            print STDOUT "503 Error: Sorry, that mail header is too big\n";

            no bytes;

            last HEAD_READ and return;
         }
      }

      warn "got CRLF" and next HEAD_READ if ( $buffer =~ /\r$/ ); # we hit a CRLF, skip the CR

      if ( $buffer eq "\n" )
      {
         warn 'Looks like we just saw the last header'
            and return $headers, $chars_read;
      }

      if ( $buffer =~ /\n$/ )
      {
         chomp $buffer;

         warn "hit a newline after $chars_read chars read. current header looks like ($buffer)";
         warn "   ...and that buffer string is @{[ length $buffer ]} chars long";

         # we're obviously at the end of the line for the header, but we need
         # to determine if the next line is an empty newline as well.  That
         # will tell us if we have read the final header

         if ( $buffer =~ /^[[:alpha:]]+-?[[:alnum:]-]+:/ )
         {
            # we're at the beginning of a new header

            warn "we're at the beginning of a new header";

            my ( $header_name, $header_value ) =
               split /:[[:space:]]{0,}/, $buffer, 2;

            $current_header = $header_name;

            warn "current header is '$current_header'";

            unless ( defined $header_value && length $header_value )
            {
               warn '!something did not split right!';

               warn "504 Error: encountered malformed header ($header_name)\n";

               say "504 Error: encountered malformed header";

               return;
            }

            # each header is an array ref, because some headers can occur more
            # than once (such as the "Received: blah blah" header), and in each
            # header entry there can be multiple lines (multi-line headers), so
            # each header entry is also an array ref of lines:

            $headers->{ $current_header } //= [ [] ];

            # this header we're dealing with is going to be at the bottom of
            # the array ref for all headers of the same name, so it's index
            # is going to be -1.  Since we know we are at the beginning of the
            # new header entry, this first line of a potentially multi-line
            # header is going to be at index 0.

            push @{ $headers->{ $current_header }->[-1] }, $header_value;
         }
         elsif ( $buffer =~ /^[[:space:]]+/ )
         {
            warn "In a multi-line header...($current_header)";

            unless ( defined $current_header )
            {
               # if execution comes here, we came across data in the header
               # space that was malformed

               warn "504 Error: encountered malformed header ($buffer)\n";

               say "504 Error: encountered malformed header";

               return;
            }

            # we are in the middle of a multi-line header.  push this line
            # onto the most recent occurance of the header of the same name
            # which will be at index -1 in that array ref

            push @{ $headers->{ $current_header }->[-1] }, $buffer;
         }
         else
         {
            warn "THIS ISN'T THE BEGINNING OF A NEW HEADER, NOR IS IT A MULTILINE.  SOMETHING IS EFFED UP";
         }

         undef $buffer; # clear the line buffer

      } # end of header line condition
   } # end of header read operation
   # < execution will never reach this point
}


sub get_header
{
   my ( $self, $requested_header ) = @_;

   my $headers = $self->c->stash->{mail_headers};

   return unless exists $headers->{ $requested_header };

   $requested_header = $headers->{ $requested_header };

   return wantarray ? @${ $requested_header } : ${ $requested_header }[0];
}


sub sendmsg
{
   my ( $self, $request_uri, $params ) = @_;

   my $response;
   my $request = HTTP::Request->new( GET => $request_uri, $params );
   my $status  = $self->c->handle_request( $request, \$response );

   return $response;
}

1;

__END__


