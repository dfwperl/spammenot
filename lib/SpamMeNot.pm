package SpamMeNot;
use Moose;
use namespace::autoclean;

use strict;
use warnings;

use Catalyst::Runtime 5.80;

use parent qw/ Catalyst /; # << required by Catalyst::Engine::Embeddable

BEGIN
{
   $ENV{CATALYST_ENGINE} = 'Embeddable';

   require Catalyst::Engine::Embeddable;

   # DEBUGGING and STDERR

   $ENV{CATALYST_DEBUG} ||= $ENV{DEBUG};
   $ENV{DBIC_TRACE}     ||= $ENV{DEBUG_SQL};

   open my $err, '>>/var/log/spammenot/app.log'
      or die qq{Can't log SpamMeNot Catalyst STDERR! $!};

   open STDERR, '>&', $err;
}

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
   ConfigLoader
   StackTrace
   Session
   Session::Store::FastMmap
   Session::State::Stash
/;

our $VERSION = '0.000001';

extends 'Catalyst';

# Configure the application.

__PACKAGE__->config
(
   name => 'SpamMeNot',
   default_view => 'TXT',
   alerts_to    => 'SpamMeNot Alerts <internal.server.alerts@spammenot.com>',
   disable_component_resolution_regex_fallback => 1,
   enable_catalyst_header => 0, # Send X-Catalyst header
);

# Start the application
__PACKAGE__->setup();

1;
