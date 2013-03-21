#!/usr/bin/env perl

BEGIN
{
   use POSIX;

   # give up root identity and run as nobody:nogroup ASAP
   my ( $uid, $gid ) = ( getpwnam('spammenot') )[2,3];

   die $! unless $uid && $gid;

   if ( $> == 0 )
   {
      POSIX::setgid( $gid ); # GID must be set before UID!
      POSIX::setuid( $uid );
   }
   elsif ( $> != $uid )
   {
      warn "ABORT!\n";
      die qq{$0 only runs as "spammenot", not as user with UID "$>"\n};
   }
}

BEGIN {
    $ENV{CATALYST_SCRIPT_GEN} = 40;
}

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('SpamMeNot', 'Server');

1;

=head1 NAME

spammenot_server.pl - Catalyst Test Server

=head1 SYNOPSIS

spammenot_server.pl [options]

   -d --debug           force debug mode
   -f --fork            handle each request in a new process
                        (defaults to false)
   -? --help            display this help and exits
   -h --host            host (defaults to all)
   -p --port            port (defaults to 3000)
   -k --keepalive       enable keep-alive connections
   -r --restart         restart when files get modified
                        (defaults to false)
   -rd --restart_delay  delay between file checks
                        (ignored if you have Linux::Inotify2 installed)
   -rr --restart_regex  regex match files that trigger
                        a restart when modified
                        (defaults to '\.yml$|\.yaml$|\.conf|\.pm$')
   --restart_directory  the directory to search for
                        modified files, can be set multiple times
                        (defaults to '[SCRIPT_DIR]/..')
   --follow_symlinks    follow symlinks in search directories
                        (defaults to false. this is a no-op on Win32)
   --background         run the process in the background
   --pidfile            specify filename for pid file

 See also:
   perldoc Catalyst::Manual
   perldoc Catalyst::Manual::Intro

=head1 DESCRIPTION

Run a Catalyst Testserver for this application.

=head1 AUTHORS

Catalyst Contributors, see Catalyst.pm

=head1 COPYRIGHT

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

