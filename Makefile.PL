use 5.006;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'IPC::Run::Simple',
    VERSION_FROM      => 'lib/IPC/Run/Simple.pm', # finds $VERSION
    PREREQ_PM         => {},
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/IPC/Run/Simple.pm', # retrieve abstract from module
       AUTHOR         => 'Steve Fink <sfink@cpan.org>') : ()),
);
