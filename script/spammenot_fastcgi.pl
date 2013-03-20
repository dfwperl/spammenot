#!/usr/bin/env perl

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

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('SpamMeNot', 'FastCGI');

1;

=head1 NAME

spammenot_fastcgi.pl - Catalyst FastCGI

=head1 SYNOPSIS

spammenot_fastcgi.pl [options]

 Options:
   -? -help      display this help and exits
   -l --listen   Socket path to listen on
                 (defaults to standard input)
                 can be HOST:PORT, :PORT or a
                 filesystem path
   -n --nproc    specify number of processes to keep
                 to serve requests (defaults to 1,
                 requires -listen)
   -p --pidfile  specify filename for pid file
                 (requires -listen)
   -d --daemon   daemonize (requires -listen)
   -M --manager  specify alternate process manager
                 (FCGI::ProcManager sub-class)
                 or empty string to disable
   -e --keeperr  send error messages to STDOUT, not
                 to the webserver
   --proc_title  Set the process title (if possible)

=head1 DESCRIPTION

Run a Catalyst application as fastcgi.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
