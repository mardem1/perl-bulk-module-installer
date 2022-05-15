#!perl

use utf8;

use 5.010;

use strict;
use warnings;

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
    Module:Starter
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
    Test:::WWW:Mechanize
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
    Test::more
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
    Win32API::FIle
    Win32API::Net
    Win32API::Registry
    WWW::Mechanize
    WWW:Mechanize
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

);

my @output = `cmd.exe /c cpan -l`;

my %installed_module_version = ();

foreach my $line ( @output ) {
    if ( 'Loading internal logger. Log::Log4perl recommended for better logging' eq $line ) {
        next;
    }

    my @t = split /\s+/, $line;
    $installed_module_version{ $t[ 0 ] } = $t[ 1 ];
}

my %modules_need_to_install   = ();
my %modules_already_installed = ();

foreach my $module ( @modules_to_install ) {
    if ( exists $installed_module_version{ $module } ) {
        $modules_already_installed{ $module } = undef;
    }
    else {
        $modules_need_to_install{ $module } = undef;
    }
}

use Data::Dumper qw( Dumper );

say '';
say 'modules_already_installed: '
    . scalar( keys %modules_already_installed ) . "\n"
    . Dumper( \%modules_already_installed );
say '';
say 'modules_need_to_install:' . scalar( keys %modules_need_to_install ) . "\n" . Dumper( \%modules_need_to_install );
say '';

my %modules_install_ok     = ();
my %modules_install_failed = ();

foreach my $module ( reverse sort keys %modules_need_to_install ) {
    my $start = localtime;
    say '# ' . $start . ' - install module - ' . $module;
    say 'cmd.exe /c cpanm ' . $module;
    say '';
    my $exitcode = system( 'cmd.exe', '/c', 'cpanm', $module );
    say '';
    my $end    = localtime;
    my $action = '';

    if ( $exitcode ) {
        $action = 'failed';
        $modules_install_failed{ $module } = undef;
    }
    else {
        $action = 'success';
        $modules_install_ok{ $module } = undef;
    }

    say '# ' . $end . ' - install module - ' . $module . ' - ' . $action;

    delete $modules_need_to_install{ $module };

    say '# modules_need_to_install left - ' . scalar( keys %modules_need_to_install );
}

say '';
say '# summary';
say 'modules_install_failed: ' . scalar( keys %modules_install_failed ) . "\n" . Dumper( \%modules_install_failed );
say '';
say 'modules_install_ok:' . scalar( keys %modules_install_ok ) . "\n" . Dumper( \%modules_install_ok );
say '';

__END__


__END__

#-----------------------------------------------------------------------------

=pod

=encoding utf8

=head1 NAME

InstallCpanModules.pl

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

