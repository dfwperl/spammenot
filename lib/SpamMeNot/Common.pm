package SpamMeNot::Common;

use strict;
use warnings;

use Exporter;

use lib './lib';

use vars qw(
   $TIMEOUT          $MAX_SAFE_READLINE
   $APP_SERVER_HOST  $APP_SERVER_PORT
);

our @EXPORT  = qw(
   $TIMEOUT          $MAX_SAFE_READLINE
   $APP_SERVER_HOST  $APP_SERVER_PORT
);

our @ISA     = qw( Exporter );
our $VERSION = '0.000001';


$TIMEOUT           = 120;      # RFCs say 2 minutes
$MAX_SAFE_READLINE = 1000;     # max length (in chars*) for a "safe" line read
$APP_SERVER_HOST   = 'localhost'; # catalyst application host
$APP_SERVER_PORT   = 25252;    # listening port of catalyst application

# *chars - as in "UTF-8" encoded characters, not fixed length ascii chars

1;

__END__

