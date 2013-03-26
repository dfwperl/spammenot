#!/usr/bin/env perl

use lib 'lib';
use SpamMeNot::DropPerms; # immediately drop root permissions

BEGIN { $ENV{CATALYST_SCRIPT_GEN} = 40; }

use Catalyst::ScriptRunner;
Catalyst::ScriptRunner->run('SpamMeNot', 'Server');

1;
