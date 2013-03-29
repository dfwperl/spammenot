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

   binmode $err, ':unix:encoding(UTF-8)';
   binmode STDIN, ':unix:encoding(UTF-8)';
   binmode STDOUT, ':unix:encoding(UTF-8)';
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

my $default_mail_name = qx{/bin/hostname -f}; chomp $default_mail_name;

__PACKAGE__->config
(
   name         => 'SpamMeNot',
   default_view => 'TXT',
   disable_component_resolution_regex_fallback => 1,
   'Plugin::Session' => { expires => 120 }
);

__PACKAGE__->config( host_mail_name => $default_mail_name )
   unless __PACKAGE__->config->{host_mail_name};

# Start the application
__PACKAGE__->setup();

1;
