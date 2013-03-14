package SpamMeNot;

use strict;
use warnings;

use Catalyst::Runtime;

# Set flags and add plugins for the application
#
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use parent qw/ Catalyst /;

BEGIN
{
   $ENV{CATALYST_ENGINE} = 'Embeddable';

   require Catalyst::Engine::Embeddable;
}

BEGIN
{
   # DEBUGGING and STDERR

   $ENV{CATALYST_DEBUG} ||= $ENV{DEBUG};

   $ENV{DBIC_TRACE}     ||= $ENV{DEBUG_SQL};

   open my $err, '>>/var/log/SpamMeNot/app.log'
      or die qq{Can't log SpamMeNot Catalyst STDERR! $!};

   open STDERR, '>&', $err;
}

our $VERSION = '0.000001';

use Catalyst qw/
   ConfigLoader
   Static::Simple
   StackTrace
   Unicode
/;

# Configure the application.

__PACKAGE__->config
(
   name => 'SpamMeNot',
   default_view => 'TXT',
   alerts_to    => 'SpamMeNot Alerts <internal.server.alerts@spammenot.com>',
);

# Start the application
__PACKAGE__->setup();


1;
