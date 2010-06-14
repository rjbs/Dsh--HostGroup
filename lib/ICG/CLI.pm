
=head1 NAME

ICG::CLI - command-line interfaces made totally awesome

=head1 VERSION

 $Id$

=head1 SYNOPSIS

  use strict;
  use warnings;

  use ICG::CLI;
  use Frob;
  use Widget;
  our $VERSION = 1.0;

  my ($opts, $usage) = describe_options(
    "got: usage: got %o [ file1 file2 ... ]",
    [ "widgitify|w" => "enwidgetify everything!" ],
  );

  say "widgets going online";

  my @widgets = Widget->get_all;
  push @widgets, map { $_->as_widget } Frob->get_all if ($opts->{widgitify});

  whisper "wow, we survived!";

=head1 DESCRIPTION

ICG::CLI provides a few utility subroutines to make it easy to write a command
line utility without resorting to wicked, nasty hacks.

All scripts should use ICG::CLI.

=head1 FUNCTIONS

=cut

package ICG::CLI;

use strict;
use warnings;

use File::Basename ();
use File::Spec ();
use File::Temp ();
use FindBin ();
use Getopt::Long::Descriptive 0.082 qw(prog_name);
use Term::ReadKey ();
use Sub::Install ();
use Log::Speak ();

use base qw(Exporter);

our @EXPORT = qw(
  describe_options
  speak yell say whisper
  prog_name
  prompt_str prompt_yn prompt_any_key
);

# later used by &_real_ARGV
my @_real_ARGV = @ARGV;

=head2 C<< describe_options($format, @options) >>

This routine works much like the C<describe_options> routine exported by
Getopt::Long::Descriptive, with some extra goodness.

The following options are prepending to the C<@options> list:

 option  | aka | description
 loud    |  -v | set the program to high loudness (aaka --verbose)
 quiet   |  -q | set the program to low loudness
 version |     | output the program's version and exit
 help    |     | output the usage and exit

The version is determined by looking for the C<$VERSION> variable in the
calling package.

ICG::CLI will also install a speak routine in the calling
package, with behavior determined by the verbosity options.
See L<Log::Speak/speak>, as well as C<< say >>, C<< whisper
>>, and C<< yell >>.

=cut

sub describe_options {
  my ($format, @options) = @_;
  my $package = caller;

  my ($opts, $usage) = Getopt::Long::Descriptive::describe_options(
    $format,
    [ noise => [
      [ "loud|verbose|v" => "produce extra trace output"     ],
      [ "quiet|q"        => "only produce output for errors" ],   
    ], { default => 'normal' } ],
    [],
    [ "version"        => "output version, then exit"      ],
    [ "help"           => "output this message, then exit" ],
    [],
    @options
  );

  if ($opts->help) {
    print $usage->text;
    exit;
  }

  if ($opts->version) {
    no strict 'refs'; # for symbolic ref
    my $version = ${$package."::VERSION"};
    print "version: ", (defined $version ? $version : 'not defined'), "\n";
    exit;
  }

  my $noise = $opts->noise;
  Log::Speak->export_speech($package);
  Log::Speak->$noise;
  Log::Speak->output('stdout');
  
  return ($opts, $usage);
}

# we need a "called before ready" exception
for my $stub (qw(speak yell say whisper)) {
  Sub::Install::install_sub({
    as   => $stub,
    code => sub { X->throw("$stub called before options processed!") },
  });
}

=begin guts

=head2 C<< ICG::CLI::_real_ARGV() >>

This routine returns the contents of C<@ARGV> as it looked before command-line
options were processed and C<@ARGV> was rewritten.

=end guts

=cut

sub _real_ARGV { @_real_ARGV }

=head2 C<< prog_name() >>

This returns the basename of the program as invoked.  It's like checking C<$0>,
but only gives the basename, and doesn't change when $0 does.

=cut

### XXX re-exported from Getopt::Long::Descriptive

=head2 C<< prog_path() >>

This routine returns the path in which the program being run is located.  It
can, in certain edge cases, be tricked by permissions and paths.  See
L<FindBin> for more information on quirks.

=cut

sub prog_path { return $FindBin::Bin; }

=head2 C<< prog_fullname() >>

This routine returns the full path to the script being run.  It is implemented
in terms of C<prog_path>, so the same caveats apply.

=cut

sub prog_fullname {
  return File::Spec->catfile(prog_path, prog_name);
}

=head2 C<< tt_cache_dir() >>

This routine returns a path in which the program can store cached template
data.  It will create the directory if needed.

B<NOTE>: this routine may go away when ICG::CLI consumes Inline::TT whole.

=cut

sub tt_cache_dir {
  my $homedir = $ENV{HOME}; # in theory, we should use File::HomeDir; eh
  
  return File::Temp::tempdir(CLEANUP => 1) if (not -d $homedir); # unlikely

  my $path = File::Spec->catfile($homedir, '.icg_cli', prog_name, 'tt_cache');
  File::Path::mkpath($path) unless -d $path;

  return $path;
}

=head2 C<< prompt_str($prompt, \%opt) >>

This prompts a user for string input.  It can be directed to
persist until input is 'acceptable'.

Valid options are:

=over 4

=item *

B<input:> optional coderef, which, when invoked, returns the
user's response; default is to read from STDIN.

=item *

B<output:> optional coderef, which, when invoked (with two
arguments: the prompt and the choices/default), should
prompt the user; default is to write to STDOUT.

=item *

B<valid:> an optional coderef which any input is passed into
and which must return true in order for the program to
continue

=item *

B<default:> may be any string; must pass the 'valid' coderef
(if given)

=item *

B<choices:> what to display after the prompt; default is
either the 'default' parameter or nothing

=item *

B<no_valid_default:> do not test the 'default' parameter
against the 'valid' coderef

=item *

B<invalid_default_error:> error message to throw when the
'default' parameter is not valid (does not pass the 'valid'
coderef)

=back

=cut

sub prompt_str {
  my ($message, $opt) = @_;
  if ($opt->{default} && $opt->{valid} && ! $opt->{no_valid_default}) {
    X::BadValue->throw(
      $opt->{invalid_default_error} ||
        "'default' must pass 'valid' parameter"
      ) unless $opt->{valid}->($opt->{default});
  }
  $opt->{input}  ||= sub { scalar <STDIN> };
  $opt->{output} ||= sub { printf "%s [%s]: ", @_ };
  $opt->{valid}  ||= sub { 1 };

  my $response;
  while (!defined($response) || !$opt->{valid}->($response)) {
    $opt->{output}->(
      $message,
      ($opt->{choices} || $opt->{default} || ""),
    );
    $response = $opt->{input}->();
    chomp($response);
    if ($opt->{default} && ! length($response)) {
      $response = $opt->{default};
    }
  }
  return $response;
}

=head2 C<< prompt_yn($prompt, \%opt) >>

This prompts the user for a yes or no response and won't give up until it gets
one.  It returns true for yes and false for no.

Valid options are:

 default: may be yes or no, indicating how to interpret an empty response;
          if empty, require an explicit answer; defaults to empty

=cut

sub prompt_yn {
  my ($message, $opt) = @_;
  X::BadValue->throw("default must be y or n")
    if $opt->{default}
    and $opt->{default} ne 'y'
    and $opt->{default} ne 'n';

  my $choices = (not defined $opt->{default}) ? 'y/n'
              : $opt->{default} eq 'y'        ? 'Y/n'
              :                                 'y/N';

  my $response = prompt_str(
    $message,
    {
      choices => $choices,
      valid   => sub { lc($_[0]) eq 'y' || lc($_[0]) eq 'n' },
      %$opt,
    },
  );

  return lc($response) eq 'y';
}

=head2 C<< prompt_any_key($prompt) >>

This routine prompts the user to "press any key to continue."  (C<$prompt>, if
supplied, is the text to prompt with.

=cut

sub prompt_any_key {
  my ($prompt) = @_;

  $prompt ||= "press any key to continue";
  print $prompt;
  Term::ReadKey::ReadMode 'cbreak';
  Term::ReadKey::ReadKey(0);
  Term::ReadKey::ReadMode 'normal';
  print "\n";
}

1;
