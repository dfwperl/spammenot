#!/usr/bin/env perl

use strict;
use warnings;

use 5.014; # minimum supported version of Perl is 5.14
use utf8;

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

   select STDERR; $|++;
   select STDIN;  $|++;
   select STDOUT; $|++;

   $SIG{__DIE__} = sub { print STDERR 'Died: '; warn @_ };
}

use lib 'lib';

package SpamMeNot::Server;

use parent qw( Net::Server::PreFork );

use SpamMeNot::Daemon; # all the methods (routines) used by this server

my $daemon  = SpamMeNot::Daemon->new();
my $timeout = $daemon->config->{timeout};

sub process_request
{
   my $self = shift @_;

   $daemon->setup_session();

   eval # eval lets us trap alarms and thereby handle timeouts
   {
      local $SIG{ALRM} = sub { die "Timed Out!\n" };

      my $previous_alarm = alarm $timeout;

      SMTP_CONVERSATION: while ( my $line = $daemon->safe_readline() )
      {
         push @{ $daemon->session->{conversation} }, $line;

         last SMTP_CONVERSATION if $daemon->end_of_message();

         $daemon->converse( $line );

         alarm $timeout;

      } # end of SMTP_CONVERSATION

      alarm $previous_alarm;
   };

   $daemon->shutdown_session();

   print STDOUT "Timed Out after $timeout seconds."
      and return
         if $@ =~ /timed out/i;
}

package main;

warn "I'm starting a server daemon in debug mode\n" if $ENV{DEBUG};

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

