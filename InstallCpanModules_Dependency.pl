#!perl

use utf8;

use 5.010;

use strict;
use warnings;

use Carp;
use Carp::Always;

use Data::Dumper qw( Dumper );

our $VERSION = '0.01';

my @modules_to_install = qw(

    Any::Moose
    AnyDBM_File
    Apache::DBI
    Apache::Perldoc
    Apache::Pod
    App::Ack
    App::Cpan
    App::cpanminus
    App::Kit
    App::perlbrew
    App::PerlCriticUtils
    App::perlimports
    App::perlvars
    App::Smbxfer
    Attribute::Handlers
    Attribute::Lexical
    Attribute::Types
    AutoLoader
    AutoSplit
    B
    B::Asmada
    B::Assemble
    B::Bblock
    B::Bytecode
    B::C
    B::CC
    B::Debug
    B::Deobfuscate
    B::Deparse
    B::Disassembler
    B::Lint
    B::Showlex
    B::StashB::Terse
    B::Xref
    BarkeleyDB
    Benchmark
    Benchmark::Forking
    BioPerl
    Bit::Vector
    Business::ISBN
    ByteLoader
    Cache::Mmap
    Carp
    Carp::Always
    Carp::Notify
    Carton
    Catalyst
    CGI
    CGI::Simple
    CGI_Lite
    Class::Accessor
    Class::Classless
    Class::Contract
    Class::Data::Inheritable
    Class::DBI
    Class::DBI::Loader
    Class::DBI::Loader::Relationship
    Class::Load
    Class::MethodMaker
    Class::MOP
    Class::MOP::Attribute
    Class::MOP::Class
    Class::MOP::Method
    Class::Multimethods
    Class::Std
    Class::Std::Utils
    Class::Struct
    Class::Tables
    Clone::AnyDBM_FileCode::Splice
    Code::Statistics
    Color::Conversion
    Config
    Config::General
    Config::IniFiles
    Config::JSON
    Config::Scoped
    Config::Std
    Config::Tiny
    ConfigReader:::Simple
    Const::Fast
    Contextual::Return
    Contextual::ReturnCPAN
    CPAN
    CPAN-Uploader
    CPAN::Mini
    CPAN::Mini::Inject
    CPAN::Reporter
    CPAN::Reporter::PrereqCheck
    CPAN::YACSmoke
    CPANCwd
    CPANPLUS
    CPANPLUS::YACSmoke
    CPANTS
    criticism
    Cwd
    CWD
    Dancer
    DATA
    Data:::Constraint
    Data::Alias
    Data::Dump
    Data::Dump::Streamer
    Data::Dumper
    Data::DUmper
    Data::DumperData::Printer
    Data::MessagePack
    DateTime
    DB
    DBD
    DBD::AnyData
    DBD::CSV
    DBD::Gofer
    DBD::Mock
    DBD::SQLite
    DBI
    DBI::Profile
    DBI::ProfileDumper
    DBICx::TestDatabase
    DBIFatal
    DBIx::Class
    DBM
    DBM::Deep
    DB_File
    Devel::CheckOS
    Devel::Cover
    Devel::Coverage
    Devel::Declare
    Devel::DProf
    Devel::ebug
    Devel::EnforceEncapsulation
    Devel::hdb
    Devel::NYTProf
    Devel::Peek
    Devel::ptkdb
    Devel::SelfStgubber
    Devel::SelfStubber
    Devel::Size
    Devel::SmallProf
    Devel::Trace
    Device::SerialPort
    diagnostics
    Digest
    Digests
    Dist::Zilla
    Dist::Zilla::Plugin::Test::Perl::Critic
    Dist::Zilla::Plugin::Test::Perl::Critic::Subset
    Distribution::Coocker
    Distribution::Cooker
    Dumbbench
    EMail
    Email::Send::SMTP
    Email::SimpleEmail::Stuff
    Encode
    Encoding::FixLatin
    English
    Env::Sourced
    Errno
    Error
    Exception::Class
    Execption::Class
    Expect::Simple
    Exporter
    ExtUtils::Command
    ExtUtils::Embed
    ExtUtils::Install
    ExtUtils::Installed
    ExtUtils::Liblist
    ExtUtils::LiblistMakeMaker
    ExtUtils::Makemaker
    ExtUtils::MakeMaker
    ExtUtils::Manifest
    ExtUtils::MM_Any
    ExtUtils::MM_Unix
    ExtUtils::MM_Win32
    Fatal
    Fcntl
    FFI::Platypus
    File::Basename
    File::chdir
    File::CheckTree
    File::chmod
    File::Compare
    File::Copy
    File::DosGlob
    File::Find
    File::FInd
    File::Find::Closures
    File::Find::Rule
    File::Finder
    File::Glob
    File::Path
    File::pushd
    FIle::Slurp
    File::Slurp
    File::Slurper
    File::Spec
    FIle::Spec
    File::Spec::Functions
    File::stat
    File::Temp
    FileHandle
    Filter::Macro
    Find::File::Closure
    FindBin
    FynaLoader
    Getopt::Attribute
    Getopt::Clade
    Getopt::Declare
    Getopt::Easy
    Getopt::Euclid
    Getopt::Long
    Getopt::Lucid
    Getopt::Mixed
    Getopt::Std
    Git::CPAN::Patch
    Git::Critic
    Gtk
    Hash::AsObject
    Hash::Util
    Hook::LexWrap
    HTML::Mason
    HTML::Parser
    HTML::TreeBuilder
    HTTP::Date
    HTTP::Recorder
    HTTP::SimpleLinkChecker
    HTTP::Size
    Image::Info
    Image::Magic
    Image::Size
    Imager
    Inlice::C
    Inline
    Inline::C
    Inline::Java
    IO::All
    IO::Dir
    IO::File
    IO::FileHandle
    IO::Handle
    IO::Handler
    IO::HandlersIRC
    IO::InSitu
    IO::Interactive
    IO::Null
    IO::Pipe
    IO::Poll
    IO::Prompt
    IO::Pty
    IO::Scalar
    IO::Seekable
    IO::Select
    IO::Socket
    IO::Socket::INET
    IO::Tee
    IPC::Msg
    IPC::Open2
    IPC::Open3
    IPC::Open3SelfLoader
    IPC::Run
    IPC::Semaphore
    IPC::Shareable
    IPC::SysV
    JSON
    JSON::Any
    JSON::Syck
    Lexical::Alias
    lib::relative
    List::Cycle
    List::MoreUtil
    List::MoreUtils
    List::Util
    Local::Error
    Local::Math
    Log::Dispatch
    Log::Log4perl
    Log::Log4perl::Appender::DBI
    Log::Log4perl::Appender::File
    Log::Log4perl::Layout::PatternLayout
    Log::Stdlog
    LWP
    LWP::Simple
    LWPPOSIX
    Mac::PropertyList
    Mac::Speech
    Mail
    Mardem::RefactoringPerlCriticPolicies
    Mason
    Math::BigFloat
    Math::BigInt
    Math::Complex
    Math::Trig
    Matrix
    Memoize
    Memorize
    Message
    Method::Signatures
    MIDI
    MIME
    Mobule::Build::TestReporter
    Modern::Perl
    ModPerl::PerlRun
    Module::Build
    Module::Build::API
    Module::CoreList
    Module::Info::File
    Module::License::Report
    Module::Pluggable
    Module::Release
    Module::Signature
    Module::Starter
    Module::Starter::AddModule
    Module::Starter::PBP
    Module::Starter::Plugin
    Module::Starter
    Mojolicious
    Monkey::PatchNet::FTP
    Moo
    Moops
    Moose
    Moose::Exporter
    Moose::Manual
    Moose::Role
    Moose::Util::TypeConstaints
    Moose::Util::TypeConstraints
    MooseX::Declare
    MooseX::DeclareMooseX::MultiMethods
    MooseX::Param::Validate
    MooseX::Params::Validate
    MooseX::Types
    My::list::Utiln
    namespace::autoclean
    NDBM_File
    Net::hostent
    Net::MAC::Vendor
    Net::netent
    Net::Ping
    Net::protoent
    Net::servent
    Net::SMTP
    Net::SMTP::SSL
    Netr::proto
    NEXT
    Object::Iterate
    OLE
    only
    Opcode
    Package::Stash
    PadWalker
    Param::Validate
    Params::Validate
    Params::ValidationCompiler
    Parse::RecDescent
    Path::Class
    Path::Class::Dir
    Path::Class::File
    Path::ClassFile::Temp
    Path::This
    PDL
    Perl6::Builtins
    Perl6::Export::Attrs
    Perl6::Form
    Perl6::Rules
    Perl6::Slurp
    Perl::Critic
    Perl::Critic::Bangs
    Perl::Critic::CognitiveComplexity
    Perl::Critic::Community
    Perl::Critic::Compatibility
    Perl::Critic::Deprecated
    Perl::Critic::Dynamic
    Perl::Critic::Itch
    Perl::Critic::Lax
    Perl::Critic::More
    Perl::Critic::Policy
    Perl::Critic::Policy::BadStrings
    Perl::Critic::Policy::BuiltinFunctions::ProhibitReturnOr
    Perl::Critic::Policy::Catalyst::ProhibitUnreachableCode
    Perl::Critic::Policy::CodeLayout::ProhibitSpaceIndentation
    Perl::Critic::Policy::CodeLayout::TabIndentSpaceAlign
    Perl::Critic::Policy::CompileTime
    Perl::Critic::Policy::Documentation::RequirePod
    Perl::Critic::Policy::Dynamic::NoIndirect
    Perl::Critic::Policy::logicLAB::ProhibitUseLib
    Perl::Critic::Policy::logicLAB::RequirePackageNamePattern
    Perl::Critic::Policy::logicLAB::RequireParamsValidate
    Perl::Critic::Policy::logicLAB::RequireSheBang
    Perl::Critic::Policy::logicLAB::RequireVersionFormat
    Perl::Critic::Policy::Modules::ProhibitUseLib
    Perl::Critic::Policy::ProhibitImplicitImport
    Perl::Critic::Policy::ProhibitOrReturn
    Perl::Critic::Policy::ProhibitSmartmatch
    Perl::Critic::Policy::References::ProhibitComplexDoubleSigils
    Perl::Critic::Policy::RegularExpressions::RequireDefault
    Perl::Critic::Policy::Variables::NameReuse
    Perl::Critic::Policy::Variables::ProhibitLoopOnHash
    Perl::Critic::Policy::Variables::ProhibitUnusedVarsStricter
    Perl::Critic::Policy::Variables::RequireHungarianNotation
    Perl::Critic::Pulp
    Perl::Critic::RENEEB
    Perl::Critic::StricterSubs
    Perl::Critic::Swift
    Perl::Critic::Tics
    Perl::Critic::TooMuchCode
    Perl::Lint
    Perl::Metrics::Lite
    Perl::Metrics::Simple
    Perl::Tidy
    Plack
    POD
    Pod::Checker
    Pod::Coverage
    Pod::Functions
    Pod::Html
    Pod::InputOBject
    Pod::Man
    Pod::ManPod::Parser
    Pod::Parser
    Pod::Perldoc
    Pod::Perldoc::BaseTo
    Pod::Perldoc::ToRtf
    Pod::Perldoc::ToText
    Pod::Perldoc::ToToc
    Pod::PseudoPod
    Pod::SelectPod::Text
    Pod::SimplePod::Simple::Subclassing
    Pod::Spell
    Pod::Text::Termcap
    Pod::TOC
    Pod::Usage
    Pod::Webserver
    POE
    POE::Component::CPAN::YACSmoke
    POSIX
    PPI
    PPod::Checker
    PRegexp::Assemble
    Readonly
    ReadonlyX
    Regexp
    Regexp::Assemble
    Regexp::Autoflags
    Regexp::Common
    Regexp::Debugger
    Regexp::English
    Regexp::MatchContext
    Regexp::Trie
    ReturnValue
    Role::Tiny
    RPerl
    Safe
    Scalar::Util
    Scalar::UtilStoreable
    SelfLoader
    Sereal
    Sereal::Decoder
    Sereal::Encoder
    Smart::Comments
    SmokeRunner::Multi
    Socket
    Sort::Maker
    SpreadSheet::ParseExcel
    Spreadsheet::ParseExecl
    Spreadsheet::WriteExcel
    Spredsheet::WriteExcel
    Sqitch
    SQL
    SQLite
    Storable
    Storeable
    Struckt::Class
    Sub::Call::Tail
    Sub::Exporter
    Sub::Identify
    Sub::INstall
    Sub::Installer
    Sub::Name
    Surveyor::App
    Surveyor::Benchmark::GetDirectoryListing
    Sx
    Symbol
    Sys::Hostname
    Sys::Syslog
    Taint::UtilTemplate
    TAP
    TAP::Harness
    Task::Kensho
    Task::Perl::Critic
    Template::BaseToTemplate::Exception
    Template::Toolkit
    Term::ANSIColor
    Term::ANSIScreen
    Term::Carp
    Term::Complete
    Term::ReadKey
    Term::ReadLine
    Term::Rendezvous
    Test
    Test2::Tools::PerlCritic
    Test:::WWW::Mechanize
    Test::Between
    Test::Builder
    Test::Builder::Tester
    Test::Builder::Tester::Color
    Test::CheckManifest
    Test::Class
    Test::ClassTest::FileTest::Harness
    Test::Cmd
    Test::Cmd::COmmon
    Test::CSV
    Test::CSV_XS
    Test::Database
    Test::DatabaseRow
    Test::Deep
    Test::Difference
    Test::Differences
    Test::Exception
    Test::Expect
    Test::Fatal
    Test::Harness
    Test::Harness::Strap
    Test::HTML::Lint
    Test::HTML::Tidy
    Test::HTML::TidyTest::Kwalitee
    Test::Inline
    Test::LongString
    Test::Manifest
    Test::MemoryCycle
    Test::MockDBI
    Test::MockModule
    Test::MockObject
    Test::MockObject::Extends
    Test::Mojibake
    Test::More
    Test::Most
    Test::My::List::Util
    Test::NoWarnings
    Test::Number::Delta
    Test::Output
    Test::Output::Tie
    Test::Perl::Critic
    Test::Perl::Critic::Git
    Test::Perl::Critic::Progressive
    Test::Perl::Critic::XTFiles
    Test::Perl::Metrics::Lite
    Test::PerlTidy
    Test::Pod
    Test::Pod::Coverage
    Test::PodTest::Harness::Strap
    Test::Reporter
    Test::Routine
    Test::Signature
    Test::Simple
    Test::Spelling
    Test::Taint
    Test::Tutorial
    Test::Utils
    Test::Vars
    Test::Warn
    Test::WWW::Mechanize
    Test::WWW::Mechanize::PSGI
    Test::XT
    Text::Abbrev
    Text::Autoformat
    Text::CSV
    Text::CSV::Simple
    Text::CSV_XS
    Text::CVS_XS
    Text::ParseWords
    Text::Template
    Text::Template::Simple::IO
    Text::Wrap
    TGie::Timely
    Thread
    Thread::Queue
    Thread::Semaphore
    Thread::SemaphoreThread::Signal
    Throwable::Error
    Tie::Array
    Tie::Array::PackedC
    Tie::BoundedInteger
    Tie::Counter
    Tie::Cycle
    Tie::Cycle::Sinewave
    Tie::DBI
    Tie::DevNull
    Tie::DevRandom
    Tie::File
    Tie::File::Timestamp
    Tie::Handle
    Tie::Hash
    Tie::Persistent
    Tie::RefHash
    Tie::Scalar
    Tie::SecureHash
    Tie::StdArray
    Tie::STDERR
    Tie::StdHash
    Tie::StdScalar
    Tie::SubstrHash
    Tie::SyslogTee
    Tie::TextDir
    Tie::TransactHash
    Tie::VecArray
    Tie::Watch
    Time::gmtime
    Time::HiRes
    Time::HiRes::usleep
    Time::Local
    Time::localtime
    Time::tm
    Tk
    TRest::Perl::Critic
    TRest::Perl::Critic::Progresive
    Try::Tiny
    Try::TinyUNIVERSAL
    TryCatch
    Underscore
    Unicode::CharName
    Unicode::Collate
    UNIVERSAL
    User::grent
    User::pwent
    Vim::Debugger
    WeakRef
    Win32
    Win32:::Registry
    Win32::ChangeNotify
    Win32::Console
    Win32::Console::ANSI
    Win32::Event
    Win32::EventLog
    Win32::FileFileSecurity
    Win32::Internet
    Win32::IPCMutex
    Win32::NetAdmin
    Win32::NetResource
    Win32::ODBC
    Win32::OLE
    Win32::OLE::Const
    Win32::OLE::NLS
    Win32::OLE::Variant
    Win32::OSLE::Enum
    Win32::PerfLib
    Win32::PipeProcess
    Win32::Semaphore
    Win32::Service
    Win32::Sound
    Win32::TieRegistry
    Win32API::File
    Win32API::Net
    Win32API::Registry
    WWW::Mechanize
    WWW::Mechanize
    XML
    XML::Compile
    XML::Parser
    XML::Rabbit
    XML::Twig
    XSLoader
    XT::Files
    YAML
    YAML::LibYAML
    YAML::Syck
    YAML::Tiny
    YAML::XS

    String::Util
    Text::Trim

);

my %installed_module_version = ();

my %modules_already_installed = ();
my %modules_need_to_install   = ();

my %modules_install_ok     = ();
my %modules_install_failed = ();

sub ltrim { my $s = shift; $s =~ s/^\s+//;       return $s }
sub rtrim { my $s = shift; $s =~ s/\s+$//;       return $s }
sub trim  { my $s = shift; $s =~ s/^\s+|\s+$//g; return $s }

sub search_for_installed_modules
{
    %installed_module_version = ();

    my @output = `cmd.exe /c cpan -l`;

    foreach my $line ( @output ) {
        if ( 'Loading internal logger. Log::Log4perl recommended for better logging' eq $line ) {
            next;
        }

        my @t = split /\s+/, $line;
        $installed_module_version{ $t[ 0 ] } =
            ( 'undef' eq $t[ 1 ] ? undef : $t[ 1 ] );
    }

    say '';
    say 'installed_module_version: '
        . scalar( keys %installed_module_version ) . "\n"
        . Dumper( \%installed_module_version );
    say '';

    return;
}

sub reduce_modules_to_install
{
    %modules_already_installed = ();
    %modules_need_to_install   = ();

    foreach my $module ( @modules_to_install ) {
        if ( exists $installed_module_version{ $module } ) {
            $modules_already_installed{ $module } = undef;
        }
        else {
            $modules_need_to_install{ $module } = undef;
        }
    }

    say '';
    say 'modules_already_installed: '
        . scalar( keys %modules_already_installed ) . "\n"
        . Dumper( \%modules_already_installed );
    say '';
    say 'modules_need_to_install:'
        . scalar( keys %modules_need_to_install ) . "\n"
        . Dumper( \%modules_need_to_install );
    say '';

    return;
}

sub get_module_dependencies
{
    my ( $module ) = @_;

    my %dependencies = ();

    # --> Working on Perl::Critic
    # Fetching http://www.cpan.org/authors/id/P/PE/PETDANCE/Perl-Critic-1.140.tar.gz ... OK
    # Configuring Perl-Critic-1.140 ... OK
    # Module::Build~0.4204
    # ExtUtils::Install~1.46
    # Fatal

    my $now = localtime;
    say '# ' . $now . ' - check module dependencies - ' . $module;

    my @output = `cpanm --showdeps $module`;

    @output = map { trim( $_ ) } @output;

    @output =
        grep { $_ !~ /Working on/io && $_ !~ /Fetching http/io && $_ !~ /^Configuring /io && $_ !~ /^skipping /io }
        @output;

    %dependencies = map {
        my @t = split /~/io;
        if ( ( scalar @t ) <= 1 ) {
            $t[ 0 ] => undef;
        }
        else {
            $t[ 0 ] => $t[ 1 ];
        }
    } @output;

    delete $dependencies{ 'perl' };    # not perl itself

    return %dependencies;
}

sub reduce_modules_which_are_not_installed
{
    my %dependencies = @_;

    my %not_installed = ();

    foreach my $module ( keys %dependencies ) {
        if ( !exists $installed_module_version{ $module } ) {
            $not_installed{ $module } = $dependencies{ $module };
        }
        elsif (defined $dependencies{ $module }
            && defined $installed_module_version{ $module }
            && ( 0.0 + $installed_module_version{ $module } ) < ( 0.0 + $dependencies{ $module } ) )
        {
            $not_installed{ $module } = $dependencies{ $module };    # to old version
        }
    }

    return %not_installed;
}

sub install_module_with_dep
{
    my ( $module ) = @_;

    my $start = localtime;
    say '# ' . $start . ' - analyze module - ' . $module;

    my %dep = get_module_dependencies( $module );
    if ( %dep ) {
        my $now = localtime;
        say '# ' . $now . ' - module has dependencies - ' . $module . ' - reduce installed';
        %dep = reduce_modules_which_are_not_installed( %dep );
    }

    if ( %dep ) {
        my $now = localtime;
        say '# ' . $now . ' - module - ' . $module . ' has not installed dependencies ';
        say '#' . Dumper( \%dep );

        foreach my $dep_module ( keys %dep ) {
            my $ret = install_module_with_dep( $dep_module );
            if ( $ret ) {
                my $now = localtime;
                say '# ' . $now . ' - module - ' . $module . ' - aborted - failed dependencies';
                delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

                return 1;                                      # abort!
            }
        }
    }
    else {
        my $now = localtime;
        say '# ' . $now . ' - module - ' . $module . ' - no dependencies to install';
    }

    my $ret = simple_install_module( $module );

    return $ret ? 1 : 0;
}

sub simple_install_module
{
    my ( $module ) = @_;

    if ( exists $modules_install_ok{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        my $now = localtime;
        say '# ' . $now . ' - install module - ' . $module . ' - already done - abort';

        return 0;
    }

    if ( exists $modules_install_failed{ $module } ) {
        delete $modules_need_to_install{ $module };    # delete if something wrong - should not happen

        my $now = localtime;
        say '# ' . $now . ' - install module - ' . $module . ' - already tried - abort';

        return 1;
    }

    my $install = localtime;

    my @cmd = ( 'cmd.exe', '/c', 'cpanm', $module );

    # update needs force
    if ( exists $installed_module_version{ $module } ) {
        say '# ' . $install . ' - update module - ' . $module;
    }
    else {
        say '# ' . $install . ' - install module - ' . $module;
    }

    say '# ' . ( join ' ', @cmd );
    say '';

    my $exitcode = system( @cmd );
    say '';
    my $end    = localtime;
    my $action = '';

    if ( $exitcode ) {
        $action = 'failed';
        $modules_install_failed{ $module } = undef;
    }
    else {
        $action                              = 'success';
        $modules_install_ok{ $module }       = undef;
        $installed_module_version{ $module } = 999_999_999;    # newest version - so real number not relevant.
    }

    say '# ' . $end . ' - install module - ' . $module . ' - ' . $action;

    delete $modules_need_to_install{ $module };    # remove module - don't care if faile - no retry of failed

    say '';
    say '# modules_need_to_install left - ' . scalar( keys %modules_need_to_install );
    say '# modules_install_failed: ' . scalar( keys %modules_install_failed );
    say '# modules_install_ok: ' . scalar( keys %modules_install_ok );
    say '';

    return $exitcode ? 1 : 0;
}

sub get_next_module_to_install
{
    return ( reverse sort keys %modules_need_to_install )[ 0 ];
}

sub renew_local_module_information
{
    search_for_installed_modules();

    reduce_modules_to_install();

    return;
}

sub main
{
    renew_local_module_information();

    my $install_module = get_next_module_to_install();
    while ( $install_module ) {
        install_module_with_dep( $install_module );

        my $next_module = get_next_module_to_install();
        if ( $next_module ne $install_module ) {
            $install_module = $next_module;
        }
        else {
            say '# ERROR: next module not changed ' . $next_module . ' - abort !';

            $install_module = '';
        }
    }

    say '';
    say '# summary';
    say '';
    say '# modules_install_failed: '
        . scalar( keys %modules_install_failed ) . "\n"
        . Dumper( \%modules_install_failed );
    say '';
    say '# modules_install_ok: ' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok );
    say '';

    return;
}

$| = 1;

main();

__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules_Dependency.pl

=head1 DESCRIPTION

TODO

=head1 AUTHOR

Markus Demml, mardem@cpan.com

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2022, Markus Demml

This library is free software; you can redistribute it and/or modify it 
under the same terms as the Perl 5 programming language system itself. 
The full text of this license can be found in the LICENSE file included
with this module.

=cut
