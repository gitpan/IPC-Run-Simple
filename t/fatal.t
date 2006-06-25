# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl fatal.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::Simple tests => 6;
use IPC::Run::Simple qw(:Fatal);
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ret = eval { run("echo Hello"); };
ok($ret, "Basic command can run");

eval { run("false"); };
ok($@ =~ /child exited with value 1/, 'Failing command set $ERR');

eval { run("nonexistent-command-dude"); };
ok($@ =~ /failed to run/, 'Nonexistent command reported');

$ret = eval { run(command => [ "false" ], allowed => [ 1 ]); };
ok($ret && ! $@, "Failing command with allowed exit val");

eval { run(command => [ "false" ], allowed => [ 2 ]); };
ok($@, "Failing command with disallowed exit val");
