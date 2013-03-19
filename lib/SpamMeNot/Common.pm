package SpamMeNot::Common;

use strict;
use warnings;

use Exporter;

use lib './lib';

use vars qw(
   $c @ISA @EXPORT $VERSION $WRNCOUNT $TIMEOUT @LEGAL_COMMANDS
   $MAX_HEADERS $MAX_HEADER_SIZE $MAX_MESSAGE_SIZE
);

@ISA     = qw( Exporter );
$VERSION = 1.00;
$TIMEOUT = $ENV{DEBUG} ? 600 : 10; # give the user n seconds to type a line

@LEGAL_COMMANDS = qw/
   auth  vrfy  quit  help  callforhelp  heartbeat  sendto
/;

@EXPORT = qw(
   $TIMEOUT   @LEGAL_COMMANDS   $WRNCOUNT
   $MAX_HEADERS   $MAX_HEADER_SIZE   $MAX_MESSAGE_SIZE
);

$TIMEOUT     = 120;
$MAX_HEADERS = 100;
$MAX_HEADER_SIZE = 1024 * 100;
$MAX_MESSAGE_SIZE = 52428800; # 50 megabytes


1;
