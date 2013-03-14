package SpamMeNot::Common;

use strict;
use warnings;

use Exporter;

use lib './lib';

use vars qw( $c @ISA @EXPORT $VERSION $WRNCOUNT $TIMEOUT @LEGAL_COMMANDS );

@ISA     = qw( Exporter );
$VERSION = 1.00;
$TIMEOUT = $ENV{DEBUG} ? 600 : 10; # give the user n seconds to type a line

@LEGAL_COMMANDS = qw/
   auth  vrfy  quit  help  callforhelp  heartbeat  sendto
/;

@EXPORT = qw(
   $TIMEOUT   @LEGAL_COMMANDS   $WRNCOUNT
);

1;
