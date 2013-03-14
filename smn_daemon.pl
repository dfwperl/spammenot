#!/usr/bin/perl

use strict;
use warnings;

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
BEGIN { ++$|; $SIG{__DIE__} = sub { print '' } }

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
use SpamMeNot::Common; # XXX will contain various definitions and defaults.
                       # XXX what things could we take from here and put there?

sub process_request
{
   my $self = shift @_;

   # XXX do you know what a UUID is?
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
      my $incoming_data  = {};

      MAINLOOP: while ( my $line = <STDIN> ) # XXX do you see the error here?
      {
         # strip line ending
         chomp $line;

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

            my $msg = $self->preparemsg( $incoming_data );

            unless ( defined $msg && length $msg ) {

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

         # XXX who can explain this regex?!
         my ( $arg, $val ) = split /\s*?:\s*?(?=\S)/, $line, 2;

         $incoming_data->{ $arg } = $val;

         alarm $TIMEOUT;

      } # end of MAINLOOP

      alarm $previous_alarm; # XXX extra credit: what's all this alarm business?
   };

   print STDOUT "Timed Out after $TIMEOUT seconds."
      and return
         if $@ =~ /timed out/i;
}

sub preparemsg
{
   my ( $self, $send_data ) = @_;

   my $cat_action = delete $send_data->{command};
   my @pairings   = map { $_ . '=' . $send_data->{ $_ } }, keys %$send_data;
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
   background        => 1,
   proto             => 'tcp',
   port              => 20202,
   min_servers       => 100,
   min_spare_servers => 50,
   max_spare_servers => 100,
   max_servers       => 400,
   max_requests      => 15,
   user              => 'nobody',
   group             => 'nogroup',
   log_file          => '/var/log/spammenot/server.log',
) or die "$! - $@";

$smnserver->run();
$smnserver->shutdown_sockets();

__END__

