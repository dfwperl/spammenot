#!/usr/bin/env perl

use strict;
use warnings;

use 5.014; # minimum supported version of Perl is 5.14 (solid unicode support)
use utf8;  # otherwise regexes on utf8-encode strings completely fail

BEGIN
{
   STDIN->autoflush;  # not suffering
   STDOUT->autoflush; # with
   STDERR->autoflush; # buffering

   # gracefully? deals with an anomaly in the Net::Server::PreFork module
   require Exception::Handler;
   $SIG{__DIE__} = sub { print STDERR Exception::Handler->new->trace( @_ ) };
}

use lib 'lib'; # all our modules live in $APPROOT/lib/

use SpamMeNot::DropPerms; # abandon root privileges immediately
use SpamMeNot::Daemon;    # all the methods (routines) used by this daemon

package SpamMeNot::Server;

use parent qw( Net::Server::PreFork );

# Do not be confused: the $daemon (below) is not the same as the catalyst
# backend application.  The daemon is created, configured, and launched below.
# It makes calls to the catalyst backend from within the SpamMeNot::Daemon
# module The purpose of the daemon is to be highly-available and route requests
# to the intelligent catalyst application which contains all the logic.

my $daemon  = SpamMeNot::Daemon->new()
   or say '503 Error: server exited prematurely'
      and exit 1;

my $timeout = $daemon->session->{timeout};

sub process_request
{
   my $self = shift @_;

   $daemon->start_session( $self->{server}{peeraddr} )
      or say '503 Error: failed to set up session'
         and exit 1;

   eval # eval lets us trap alarms and thereby handle timeouts
   {
      local $SIG{ALRM} = sub { die 'Timed out!' };

      my $previous_alarm = alarm $timeout;

      while ( my $line = $daemon->safe_readline() )
      {
         next if $line =~ /^_/; # no internal commands allowed to public

         if ( $daemon->converse( $line ) ) # send everything else through
         {
            say $daemon->response;

            exit if $daemon->response =~ /^\d+\sBye/;
         }
         else
         {
            say $daemon->error and exit;
         }

         alarm $timeout;
      }

      alarm $previous_alarm;
   };

   say "503 Error: Timed Out after $timeout seconds"
      and exit if $@ =~ /Timed out/;

   exit; # we really, really only want one session per fork (for security)
}

package main;

warn "I'm starting a server daemon in debug mode\n" if $ENV{DEBUG};

# warning: the log file used below must be writable by the designated user
my $smnserver = SpamMeNot::Server->new # XXX how can these options be improved?
(
   background        => 0,
   proto             => 'tcp',
   port              => 20202,
   min_servers       => 100,
   min_spare_servers => 50,
   max_spare_servers => 300,
   max_servers       => 400,
   max_requests      => 1,
   user              => 'spammenot',
   group             => 'spammenot',
   commandline       => $0,
   log_file          => '/var/log/spammenot/server.log',
) or die "$! - $@";

$smnserver->run();

$smnserver->shutdown_sockets();

__END__

