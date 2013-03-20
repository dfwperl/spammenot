<<<<<<< HEAD
#!/usr/bin/perl
=======
#!/home/superman/perl5/perlbrew/perls/perl-tommydev/bin/perl
>>>>>>> master

use strict;
use warnings;

use 5.017; # minimum supported version of Perl is 5.17

<<<<<<< HEAD
use encoding 'utf8';
=======
#use encoding 'utf8';
use utf8;
>>>>>>> master

BEGIN
{
   use POSIX;

   # give up root identity and run as nobody:nogroup ASAP
   my ( $uid, $gid ) = ( getpwnam('nobody') )[2,3];

   if ( $> == 0 )
   {
      POSIX::setgid( $gid ); # GID must be set before UID!
      POSIX::setuid( $uid );
   }
   elsif ( $> != $uid )
   {
      warn "ABORT!\n";
      die qq{$0 only runs as system user "nobody", not as user with UID "$>"\n};
   }
}

# no buffering, and shut up catalyst
<<<<<<< HEAD
BEGIN { ++$|; select STDIN; ++$|; select STDOUT; $SIG{__DIE__} = sub { print '' } }
=======
BEGIN { select STDIN; ++$|; select STDOUT; $|++; $SIG{__DIE__} = sub { warn "Died.\n"; warn @_ } }
#BEGIN { ++$|; select STDIN; ++$|; select STDOUT; }
>>>>>>> master

use HTTP::Request;
use Data::UUID;

use lib 'lib';
use SpamMeNot;

our ( $c, $UUID, $IP, $MSG_TERMINATOR, @LEGAL_COMMANDS );

$MSG_TERMINATOR = 'OMG! BACON!'; # XXX << change to RFC standard, which is?
@LEGAL_COMMANDS = qw( EHLO STARTTLS ); # XXX ...What are the legal RFC commands?

# instantiate the SpamMeNot application which is also a catalyst object
$c = SpamMeNot->new();

package SpamMeNot::Server;
use parent qw( Net::Server::PreFork );
use SpamMeNot::Common; # contains various definitions and defaults.

sub process_request
{
   my $self = shift @_;

   # UUID per request
   $UUID = Data::UUID->new()->to_string( Data::UUID->new()->create() );

   $IP = $self->{server}{peeraddr} // '<unknown peer>';

   # separating banner for each request
   # XXX log each request here... incude the $UUID, the $IP, and a timestamp

   # redefine effective warn() call to include a timestamp and the $UUID
   $SIG{__WARN__} = sub
   {
      # increment warn count
      ++$WRNCOUNT;

      # issue the warning; trailing \n prevents verbose line origin BS
      print STDERR qq($UUID [${\ scalar gmtime }] $WRNCOUNT: @_);
   };

   eval { # eval lets us trap alarms and thereby handle timeouts

      local $SIG{ALRM} = sub { die "Timed Out!\n" };

      my $previous_alarm = alarm $TIMEOUT;
      my $bytes_read     = 0;
      my $email_object   = {};

      $self->stash_headers( \*STDIN );

<<<<<<< HEAD
      use Data::Dumper;
      warn 'DUMPERING!!!';

      $self->stash_content( \*STDIN );

      my $incoming_data  = {}; # dummy variable XXX

=======
#      $self->stash_content( \*STDIN );

      my $incoming_data  = {}; # dummy variable XXX

>>>>>>> master
      MAINLOOP: for my $line ( split /\r|\n/, '' )
      {
         # check for input
         unless ( length $line )
         {
            warn "500 Error: bad syntax\n";

            print STDOUT "502 ERROR: bad syntax\n";

            return 0;
         }

         # check if done
         if ( $line =~ /^\Q$MSG_TERMINATOR\E$/o )
         {
            # we just hit the end of the message, and the $%incoming_data
            # hashref will have been populated by now

            warn "Command sequence terminator detected\n";

            warn "Preparing backend request string from input data\n";

            my $msg = $self->preparemsg( $email_object );

            unless ( defined $msg && length $msg )
            {
               warn "500 Error: Internal Server Error\n";

               print STDOUT "500 Error: Internal Server Error\n";

               return 0;
            }

            warn "Passing request to Catalyst backend\n";

            my $response = $self->sendmsg( $msg );

            if
            (
               eval { $response->can('content') } &&
               $response->is_success && $response->content
            )
            {
               warn "Printing Catalyst output to client on STDOUT\n";

               print STDOUT $response->content;

               warn "DONE\n";

               return 1;
            }
            else
            {
               warn "500 Error: Internal Server Error\n";

               print STDOUT "500 Error: Internal Server Error\n";

               return 0;
            }
         }

         # check if first argument (which will be the command)
         unless ( keys %$incoming_data )
         {
            # this is first line of input

            warn "Receiving and checking new command\n";

            $line = uc $line;

            foreach my $legal_cmd ( @LEGAL_COMMANDS )
            {
               if ( $line eq $legal_cmd )
               {
                  if ( $legal_cmd eq $MSG_TERMINATOR || $legal_cmd eq 'quit' )
                  {
                     warn "ERROR: Received message terminator or QUIT; exiting\n";

                     print STDOUT "500 Error: bad syntax\n";

                     return 0;
                  }
                  else
                  {
                     warn "New command received: $line\n";

                     $incoming_data->{command} = $line and next MAINLOOP;
                  }
               }
            }

            # somebody entered an unknown/unsupported command!
            warn "ERROR: $line\n";

            print STDOUT "500 Error: command not recognized\n";

            return 0;

         }

         $incoming_data->{ $arg } = $val;

         alarm $TIMEOUT;

      } # end of MAINLOOP

      alarm $previous_alarm; # XXX extra credit: what's all this alarm business?

      warn "client disconnected after sending $bytes_read bytes\n";
   };

   $c->stash( mail_headers => undef );

   print STDOUT "Timed Out after $TIMEOUT seconds."
      and return
         if $@ =~ /timed out/i;
}

sub stash_content
{
<<<<<<< HEAD
   my ( $file_handle ) = @_;

   my ( $chars_read, $buffer, $content ) = ( 0, '', '' );

   my $offset = $c->stash( 'body_offset' );
=======
   my ( $file_handle ) = shift @_;

   my ( $chars_read, $buffer, $content ) = ( 0, '', '' );

   my $offset = $c->stash->{body_offset};
>>>>>>> master

   die "Bad call to stash_content() -- need filehandle seek position\n"
      unless $offset;

   binmode $file_handle, ':unix:encoding(UTF-8)';
<<<<<<< HEAD
=======
#   binmode $file_handle;
>>>>>>> master

   seek $file_handle, $offset, 0;

   # protect ourselves from DOS attacks based on huge messages
   BODY_READ: while ( $chars_read += read $file_handle, $buffer, 1024 )
   {
      $content .= $buffer;

      use bytes;

      if ( length $content > $MAX_MESSAGE_SIZE )
      {
         undef $content;

         warn "503 Error: Sorry, that mail message is too big\n";

         print STDOUT "503 Error: Sorry, that mail message is too big\n";

         last BODY_READ and return;
      }
   }

   $c->stash( mail_body => $content );
}

sub read_headers
{
<<<<<<< HEAD
   warn 'read_header() called';

   my ( $self, $file_handle, $offset ) = @_;

   my ( @headers, $chars_read, $buffer, $header, $is_last_header );

   $is_last_header = 0;
   $offset       //= 0;
=======
   warn 'read_headers() called';

   my ( $self, $file_handle, $offset ) = @_;

   my ( $headers, $chars_read, $buffer, $char,
        $current_header, $is_last_header );

   $is_last_header = 0;
   $offset       //= 0;
   $headers        = {};
>>>>>>> master
   $chars_read     = 0;

   binmode $file_handle, ':unix:encoding(UTF-8)';

   warn "going to try to get a header from file handle";

   seek $file_handle, 0, 0;

   # protect ourselves from DOS attacks based on huge messages
<<<<<<< HEAD
   HEAD_READ: while ( $chars_read += read $file_handle, $buffer, 1, $offset )
   {
      $offset += $chars_read;
=======
   HEAD_READ: while ( $chars_read += read $file_handle, $char, 1 )
   {
      $offset += $chars_read;
      $buffer .= $char;
>>>>>>> master

      {
         use bytes;

         if ( length $buffer > $MAX_HEADER_SIZE )
         {
            warn "503 Error: Sorry, that mail header is too big (@{[ length $buffer ]} bytes) ($buffer)\n";

            print STDOUT "503 Error: Sorry, that mail header is too big\n";

            no bytes;

            last HEAD_READ and return;
         }
      }

      warn "got CRLF" and next HEAD_READ if ( $buffer =~ /\r$/ ); # we hit a CRLF, skip the CR

<<<<<<< HEAD
      if ( $buffer =~ /\n$/ )
      {
         warn "hit a newline after $chars_read chars read. current header looks like ($buffer)";
=======
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
>>>>>>> master

         # we're obviously at the end of the line for the header, but we need
         # to determine if the next line is an empty newline as well.  That
         # will tell us if we have read the final header

<<<<<<< HEAD
         chomp $buffer;

         warn "peeking ahead at the next two chars in the file handle";

         # look ahead 2 character (2 chars instead of 1 to accunt for CRLF)
         my $peek_buffer = '';
         my $peek_read   = 0;

         warn "peek buffer is @{[ length $peek_buffer ]} chars long before peek read";

         seek $file_handle, 0, 0;

         PEEK: while ( $peek_read = read $file_handle, $peek_buffer, 2, $chars_read )
         {
            warn 'peeked!';

            last PEEK;
         }

         warn "read $peek_read chars; the next two chars were ($peek_buffer)";

         if ( $peek_buffer =~ /(?:\r|\n)/ )
         {
            warn 'Looks like we just saw the last header';

            ++$chars_read;
            ++$is_last_header;
         }

         push @headers, $buffer;

         return \@headers, $chars_read if $is_last_header;

         $buffer = $peek_buffer;
      }
   }

   warn 'this is bad ' x 10;
   return;
}

sub stash_headers
{
   my ( $self, $file_handle ) = @_;
   my $headers = {};

   warn "stash_headers() is going to go get the mail headers...";

   my ( $raw_headers, $body_offset ) = $self->read_headers( $file_handle );

   for my $header ( @$raw_headers )
   {
      #my ( $header_name, $header_value ) = ( $header ) =~ /([^\W]+)\W{0,}:\W{0,}(.*)/;
      my ( $header_name, $header_value ) = split /\W{0,}:\W{0,}/, $header, 2;

      say "($header)";
      say "($header_name) => ($header_value)";

      unless ( defined $header_value && length $header_value )
      {
         warn "504 Error: encountered malformed header ($header)\n";

         print STDOUT "504 Error: encountered malformed header\n";

         return;
      }

      $headers->{ $header_name } //= [];

      push @{ $headers->{ $header_name } }, $header_value;
   }

   warn 'NO MORE HEADERRRRRRRRRRZZZZZZZZZZZZZZ';

   $c->stash( body_offset  => $body_offset );
   $c->stash( mail_headers => $headers );
=======
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

sub stash_headers
{
   my ( $self, $file_handle ) = @_;

   warn "read_headers() is going to go get the mail headers...";

   my ( $headers, $body_offset ) = $self->read_headers( $file_handle );

   use Data::Dumper;
   say Dumper $headers;

   $c->stash( { body_offset => $body_offset, mail_headers => $headers } );
>>>>>>> master
}

sub get_header
{
   my ( $self, $requested_header ) = @_;

   my $headers = $c->stash->{mail_headers};

   return unless exists $headers->{ $requested_header };

   $requested_header = $headers->{ $requested_header };

   return wantarray ? @${ $requested_header } : ${ $requested_header }[0];
}

sub preparemsg
{
   my ( $self, $send_data ) = @_;

   my $cat_action = delete $send_data->{command};
   my @pairings   = map { $_ . '=' . $send_data->{ $_ } } keys %$send_data;
   my $cat_query  = join('&', @pairings); # XXX how could this line be better written?

   return '' unless $cat_action && $cat_query;

   return qq{/$cat_action?$cat_query};
}

sub sendmsg
{
   my ( $self, $requestURI ) = @_;

   warn qq(Asking SpamMeNot backend for @{[
      length $requestURI ? "\"$requestURI\"" : 'nothing at all' ]}\n);

   my $response;
   my $request = HTTP::Request->new( 'GET', $requestURI ); # XXX problem?
   my $status  = $c->handle_request( $request, \$response );

   return $response;
}

package main;

if ( $ENV{DEBUG} ) { warn "I'm starting a server daemon in debug mode\n"; }

my $smnserver = SpamMeNot::Server->new # XXX how can these options be improved?
(
   background        => 0,
   proto             => 'tcp',
   port              => 20202,
   min_servers       => 100,
   min_spare_servers => 50,
   max_spare_servers => 100,
   max_servers       => 400,
   max_requests      => 15,
   user              => 'nobody',
   group             => 'nogroup',
   log_file          => '/var/log/spammenot/server.log', # !! must be writable by "nobody"
   commandline       => "sudo -E /home/superman/perl5/perlbrew/perls/perl-tommydev/bin/perl $0",
) or die "$! - $@";

$smnserver->run();

$smnserver->shutdown_sockets();

__END__

