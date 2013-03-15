use strict;
use warnings;

use SpamMeNot;

my $app = SpamMeNot->apply_default_middlewares(SpamMeNot->psgi_app);
$app;

