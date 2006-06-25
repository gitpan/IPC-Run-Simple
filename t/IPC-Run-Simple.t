use lib '/home/sfink/sfinkware/IPC-Run-Simple/lib';

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl IPC-Run-Simple.t'

#########################

use Test::Simple tests => 10;
use IPC::Run::Simple qw(:all);
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $ret = run("echo Hello");
ok($ret, "Basic command can run");

$ret = run("false");
ok(! $ret, "Failing command returns false");
ok($ERR =~ /child exited with value 1/, 'Failing command set $ERR');

$ret = run("nonexistent-command-dude");
ok(! $ret, "Nonexistent command returns false");
ok($ERR =~ /failed to run/, 'Nonexistent command reported');

$ret = run(command => [ "false" ], allowed => [ 1 ]);
ok($ret, "Failing command with allowed exit val");

$ret = run(command => [ "false" ], allowed => [ 2 ]);
ok(! $ret, "Failing command with disallowed exit val");

$ret = run(command => "false", allowed => [ 1 ]);
ok($ret, "Passing in command as a string");

$ret = run(command => "echo Hello", allowed => [ 1 ]);
ok(! $ret, "Successful command that was not supposed to succeed");
