use strict;
use warnings;
package Dsh::Group::App;
use base 'App::Cmd::Simple';

=head1 NAME

group - look up machines and groups

=head1 VERSION

version 2.00

=cut

our $VERSION = '2.00';

use File::Basename;
use Dsh::Group::Groups;
use List::MoreUtils qw(uniq);

sub usage_desc {
  "%c %o <groupname ...>",
}

sub opt_spec {
  [ "exclude|V=s@",   "exclude the given host/group(s) from output"        ],
  [ "reverse|r",      "find groups for a machine, not machines in a group" ],
  [
    "mode" => [
      [ "intersection|i", "given many groups, find hosts in all of them" ],
      [ "union|u",        "given many groups, find hosts represented" ],
      [ "list|l",         "list all groups" ],
    ],
    { default => 'union' },
  ]
}

sub execute {
  my ($self, $opt, $args) = @_;

  if ($opt->{mode} eq 'list') {
    $self->usage_error("--list does not take any arguments") if @$args;
  } else {
    $self->usage_error("you need to pass some host/group names") if ! @$args;
  }

  my @answers;

  if ($opt->{mode} eq 'list') {
    print("$_\n") for sort Dsh::Group::Groups->all_groups;
    return;
  }

  if ($opt->{mode} eq 'union') {
    @answers = $opt->{reverse}
             ? Dsh::Group::Groups->groups_for_hosts($args)
             : Dsh::Group::Groups->hosts_for_groups($args);
  } elsif ($opt->{mode} eq 'intersection') {
    @answers = $opt->{reverse}
             ? Dsh::Group::Groups->intersecting_groups_for_hosts($args)
             : Dsh::Group::Groups->hosts_for_intersecting_groups($args);
  }

  my %exclude;
  if ($opt->{reverse}) {
    %exclude = map {; $_ => 1 } @{ $opt->{exclude} };
  } else {
    for my $v (@{ $opt->{exclude} }) {
      if (my @hosts = Dsh::Group::Groups->hosts_for_groups([ $v ])) {
        @exclude{@hosts} = (1) x @hosts;
      } else {
        $exclude{$v} = 1;
      }
    }
  }

  print "$_\n" for grep { ! $exclude{ $_ } } @answers;
}

1;
