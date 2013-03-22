package SpamMeNot::Common;

use strict;
use warnings;

use Exporter;

use lib './lib';

use vars qw(
   $TIMEOUT          @SUPPORTED_COMMANDS     $MAX_SAFE_READLINE
   $MAX_HEADERS      $MAX_HEADER_LENGTH      $MAX_MESSAGE_SIZE
   $WRNCOUNT         $APP_SERVER_HOST        $APP_SERVER_PORT
   $READY_FOR_DATA   $MAX_CONVERSATION
);

our @ISA     = qw( Exporter );
our $VERSION = '0.000001';
our @EXPORT  = qw(
   $TIMEOUT          @SUPPORTED_COMMANDS     $MAX_SAFE_READLINE
   $MAX_HEADERS      $MAX_HEADER_LENGTH      $MAX_MESSAGE_SIZE
   $WRNCOUNT         $APP_SERVER_HOST        $APP_SERVER_PORT
   $READY_FOR_DATA   $MAX_CONVERSATION
);

@SUPPORTED_COMMANDS = qw/
   HELO     EHLO     AUTH     RSET     NOOP     HELP
   MAIL     RCPT     DATA     VRFY     QUIT     DFWPM
/;

$APP_SERVER_HOST   = 'localhost'; # catalyst application host
$APP_SERVER_PORT   = 25252;    # listening port of catalyst application
$TIMEOUT           = 120;      # RFCs say 2 minutes
$MAX_HEADERS       = 100;      # max number of headers before we shut it down
$MAX_HEADER_LENGTH = 1000;     # max length (in chars*) for any given header
$MAX_MESSAGE_SIZE  = 52428800; # max size for a message - 50 megabytes
$MAX_SAFE_READLINE = 1000;     # max length (in chars*) for a "safe" line read
$MAX_CONVERSATION  = 30;       # max number of SMTP commands allowed per session
$READY_FOR_DATA    = qr/^DATA\r?\n$/;

# *chars - as in "UTF-8" encoded characters, not fixed length ascii chars

1;

__END__

