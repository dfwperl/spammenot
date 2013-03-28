package SpamMeNot;
use Moose;
use namespace::autoclean;

use strict;
use warnings;

use Catalyst::Runtime 5.80;

BEGIN
{
   # DEBUGGING and STDERR

   $ENV{CATALYST_DEBUG} ||= $ENV{DEBUG};
   $ENV{DBIC_TRACE}     ||= $ENV{DEBUG_SQL};

   open my $err, '>>', '/var/log/spammenot/app.log'
      or die "Can't log SpamMeNot Catalyst errors! $!";

   open STDERR, '>&', $err;

   binmode $err, ':unix:encode(UTF-8)';
   binmode STDIN, ':unix:encode(UTF-8)';
   binmode STDOUT, ':unix:encode(UTF-8)';
}

# Set flags and add plugins for the application
#   - Documentation for these plugins can be found on metacpan.org

use Catalyst qw/
   Unicode
   ConfigLoader
   StackTrace
   Session
   Session::Store::FastMmap
   Session::State::Cookie
/;

our $VERSION = '0.000001';

extends 'Catalyst';

# Configure the application.

__PACKAGE__->config
(
   default_view => 'TXT',
   disable_component_resolution_regex_fallback => 1,
);

# Start the application
__PACKAGE__->setup();

1;
