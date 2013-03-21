package SpamMeNot::DropPerms;

use strict;
use warnings;

BEGIN
{
   use POSIX;

   # give up root identity and run as spammenot:spammenot ASAP
   my ( $uid, $gid ) = ( getpwnam 'spammenot' )[ 2, 3 ];

   die $! unless $uid && $gid;

   if ( $> == 0 )
   {
      POSIX::setgid( $gid ); # GID must be set before UID!
      POSIX::setuid( $uid );
   }
   elsif ( $> != $uid )
   {
      warn <<__ABORT__ and exit 1;
** ABORT! **
   This application only runs as the "spammenot" user, not as your user
   account with ID: $>

   If you don't have a limited-permissions system account with this user
   name, please create one: spammenot
__ABORT__
   }
}

1;
