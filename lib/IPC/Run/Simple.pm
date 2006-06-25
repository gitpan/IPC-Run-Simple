package IPC::Run::Simple;

use 5.006;
use strict;
use warnings;

our $VERSION = '1.0';

our $ERR;
our $Fatal = 0;

sub import {
    my $pkg = shift;
    my $callpkg = caller;

    no strict 'refs';

    foreach ('run', @_) {
        if (/^\w/) {
            *{"$callpkg\::$_"} = \&{"$pkg\::$_"};
        } elsif (/^&(.*)/) {
            *{"$callpkg\::$1"} = \&{"$pkg\::$1"};
        } elsif (/^$(.*)/) {
            *{"$callpkg\::$1"} = \${"$pkg\::$1"};
        } elsif (/^:(.*)/) {
            if ($1 eq 'all') {
                *{"$callpkg\::$_"} = \&{"$pkg\::$_"} foreach qw(run);
                *{"$callpkg\::$_"} = \${"$pkg\::$_"} foreach qw(ERR);
            } elsif ($1 eq 'Fatal') {
                $Fatal = 1;
            }
        } else {
            die "Unrecognized import '$_'";
        }
    }
}

sub run {
    die "no arguments" if @_ == 0;

    my %options;
    if (@_ > 1 && ref($_[1])) {
        %options = @_;
    } else {
        $options{command} = \@_;
    }

    undef $ERR;

    # system() by default spews out a warning if the command cannot be
    # found. Setting $SIG{__WARN__} suppresses it, but oddly I cannot
    # capture the error message. I would guess that it's only issued
    # in the subprocess, but when I print out the pid it says it's the
    # parent. So I'm at a loss. Oh well; at least it doesn't spew it
    # out to STDERR this way.
    local $SIG{__WARN__} = sub { $ERR = shift; };

    system(@{ $options{command} });
    return 1 if ($? == 0);

    if ($? == -1) {
        $ERR ||= "failed to run external command ($!)";
    } elsif ($? & 127) {
        $ERR = sprintf("child died with signal %d, %s coredump",
                       ($? & 127), ($? & 128) ? "with" : "without");
    } else {
        my $exitval = ($? >> 8);
        $ERR = "child exited with value $exitval";
        if (grep { $exitval == $_ } @{ $options{allowed} || [] }) {
            return $exitval;
        }
    }

    die $ERR if $Fatal;
    return;
}

1;
__END__

=head1 NAME

IPC::Run::Simple - Simple system() wrapper

=head1 SYNOPSIS

  # Run a command and check whether it failed
  use IPC::Run::Simple;
  run("echo Hello, O Cruel World")
    or die "Command failed";

  # Describe the failure
  use IPC::Run::Simple qw($ERR);
  run("echo Hello, O Cruel World")
    or die "Command failed: $ERR";

  # Use the :all tag instead of explicitly requesting $ERR
  use IPC::Run::Simple qw(:all);
  run("echo Hello, O Cruel World")
    or die "Command failed: $ERR";

  # Die with error message if command does not return 0
  use IPC::Run::Simple qw(:Fatal);
  run("echo Hello, O Cruel World");

  # Allow other exit values without dying
  use IPC::Run::Simple qw(:Fatal);
  run(command => [ "echo", "Hello, O Cruel World!" ],
      allowed => [ 1, 2, 5 ]);

=head1 DESCRIPTION

This module is intended to be a very simple, straightforward wrapper
around the C<system()> call to make it behave more like other builtins.

C<run()> will return a true value if the command was executed and
return a successful status code, and false otherwise. The reason for
the failure will be stored in the C<$IPC::Run::Simple::ERR> variable
(which is just C<$ERR> if you import either C<$ERR> or C<:all>). The
description of the reason was pulled almost directly from the
C<system()> documentation.

Optionally, you can import the C<:Fatal> tag, which will cause
C<run()> to C<die()> with an appropriate message if the command fails
for any reason.

If you wish to allow nonzero exit values but still want to trap
unexpected errors, you may use an expanded call syntax. Call C<run()>
with a set of key=>value pairs. The two implemented keys are
C<command> (an array reference containing the command to run) and
C<allowed> (an array reference of exit values that are allowed without
causing C<run()> to return false or throw an exception.)

This module was inspired by a thread on PerlMonks, where pjf asked
whether there was a simple system() wrapper:
http://www.perlmonks.org/?node_id=557107

In response, I wrote this module.

=head2 EXPORT

By default, the C<run()> function is exported into the caller's
namespace. C<$ERR> can be optionally exported. The C<:all> tag will
export both C<run()> and C<$ERR>.

The C<:Fatal> tag will cause all errors to be fatal.


=head1 SEE ALSO

L<IPC::Run3> also uses true/false to indicate success or failure, and
also implements several other features (it aims to replace
C<system()>, backticks, and piped opens, whereas this module is purely
a wrapper for C<system()>.)

L<IPC::Run> handles everything that this module does, everything that
IPC::Run3 does, and will attempt to embed a microcontroller in your
kitchen sink if you let it.

L<IPC::Cmd> is similar to (and can use) IPC::Run3, but can also work
via L<IPC::Open3> or builtin code.

All of the above have been tested on Windows, unlike this module.

=head1 AUTHOR

Steve Fink E<lt>sfink@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Steve Fink

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
