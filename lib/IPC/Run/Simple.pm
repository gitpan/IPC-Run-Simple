package IPC::Run::Simple;

use 5.006;
use strict;
use warnings;

our $VERSION = '1.3';

our $ERR;
our $Fatal = 0;

our @EXPORT = qw(run);

sub _export_sub {
    my ($callpkg, $subname, $thispkg, $fatal) = @_;

    no strict 'refs';

    my $sub;
    if ($subname eq 'run') {
        $sub = $fatal ? \&_run_fatal : \&_run_nonfatal;
    } else {
        $sub = \&{"$thispkg\::$subname"};
    }

    *{"$callpkg\::$subname"} = $sub;
}

sub import {
    my $pkg = shift;
    my $callpkg = caller;

    no strict 'refs';

    $Fatal = grep { $_ eq ':Fatal' } @_;

    foreach (@EXPORT, @_) {
        if (/^\w/) {
            _export_sub($callpkg, $_, $pkg, $Fatal);
        } elsif (/^&(.*)/) {
            _export_sub($callpkg, $1, $pkg, $Fatal);
        } elsif (/^$(.*)/) {
            *{"$callpkg\::$1"} = \${"$pkg\::$1"};
        } elsif (/^:(.*)/) {
            if ($1 eq 'all') {
                _export_sub($callpkg, $_, $pkg, $Fatal) foreach qw(run);
                *{"$callpkg\::$_"} = \${"$pkg\::$_"} foreach qw(ERR);
            } elsif ($1 eq 'Fatal') {
                # Already handled
            } else {
                die "Unrecognized import tag '$1'";
            }
        } else {
            die "Unrecognized import '$_'";
        }
    }
}

sub run {
    die "no arguments" if @_ == 0;

    # Wacky argument handling to allow either a list of arguments to
    # be passed in (a la system()), or key=>value pairs (the
    # difference is detectable because one of the values must be an
    # array ref.)
    my %options;
    if ((@_ % 2) == 0) {
        %options = @_;
        if (grep { ref($_) } values %options) {
            my $cmd = $options{command};
            die "no command given" if ! defined $cmd;
            $cmd = [ $cmd ] if ! ref($cmd);
            $options{command} = $cmd;
        } else {
            %options = (command => \@_ );
        }
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

    # Handle a successful return. This isn't completely
    # straightforward, because the caller might not allow a zero
    # return value.
    if ($? == 0) {
        if (defined $options{allowed} &&
            ! grep { $_ == 0 } @{ $options{allowed} })
        {
            $ERR = "child exited with value 0";
            die $ERR if $Fatal;
            return 0;
        }
        return "0 but true";
    }

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

sub _run_fatal {
    local $Fatal = 1;
    run(@_);
}

sub _run_nonfatal {
    local $Fatal = 0;
    run(@_);
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

=head1 BUGS AND LIMITATIONS

The C<$ERR> variable is shared by all packages. So if package A calls
C<run("a")>, which sets C<$ERR>, and then calls C<b_func()>, which is
defined in package B and calls C<run("b")>, then after C<b_func()>
returns C<$ERR> will no longer be set to the value resulting from the
C<run("a")>; its value will have been overwritten by the call to
C<run("b")>..

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

Ricardo SIGNES pointed out a bug resulting from misuse of a
package-scoped C<$Fatal> variable.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Steve Fink

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.

=cut
