use strict;
use warnings;
package Dsh::Group::Groups;

=head1 NAME

Dsh::Group::Groups - look up machines and groups

=head1 VERSION

version 1.000

=cut

our $VERSION = '1.000';

use Carp ();
use Clone;
use File::Find::Rule;
use List::MoreUtils;
use Params::Util qw(_CLASS);

=head1 METHODS

=cut

my %FOR_ROOT;

=head2 for_root

  my $groups = Dsh::Group::Groups->for_root( $dsh_groups_root );

If no root is supplied, the env var C<DSH_GROUP_ROOT> is consulted.  If
that's not defined F</etc/dsh/group> is used.  Groups objects are cached.

=cut

sub default_host_class { 'Dsh::Group::Host' }
sub default_group_root { '/etc/dsh/group/'  };

sub for_root {
  my ($class, $root, $arg) = @_;
  $root ||= $ENV{DSH_GROUP_ROOT} || $class->default_group_root;
  $arg  ||= {};

  my $effective_arg = {
    host_class => $arg->{host_class} || $class->default_host_class,
  };

  my $arg_str = join \0,
                map { $_, $effective_arg->{$_} }
                sort keys %$effective_arg;

  return $FOR_ROOT{ "$root$arg_str" } ||= $class->_new($root, $effective_arg);
}

sub _new {
  my ($class, $root, $arg) = @_;

  Carp::croak("illegal host_class: $arg->{host_class}")
    unless _CLASS($arg->{host_class});

  eval "require $arg->{host_class}; 1" or die $@;

  return bless {
    root       => $root,
    host_class => $arg->{host_class},
  } => $class;
}

sub _self {
  return $_[0] if ref $_[0];
  return $_[0]->for_root;
}

sub _root { $_[0]{root} }

sub _group_hosts {
  my ($invocant) = @_;
  my $self = $invocant->_self;

  return $self->{_group_hosts} if $self->{_group_hosts};

  my $root  = $self->_root;
  my $hosts = $self->{_group_hosts} = {};

  my @group_files = File::Find::Rule->file->in($root);

  warn "going to look for files in $root\n";
  GROUPFILE: for my $file (@group_files) {
    warn "considering $file\n";
    if (-l $file) {
      my $target = readlink $file;
      next GROUPFILE unless -e $target;
    }

    (my $group = $file) =~ s{^\Q$root\E/}{}g;
    warn "truncated name to $group\n";
    next if $group =~ m{(?:^|/)\.};
    warn "proceding; was not a dotfile\n";

    open my $fh, '<', $file or die "couldn't open group file for $group: $!";
    my @lines = grep { $_ !~ /^#/ } <$fh>;
    chomp @lines;
    $hosts->{ $group } = \@lines;
  }

  return $hosts;
}

=head2 groups_for_hosts

  my @groups = $groups->groups_for_hosts($host);

  my @groups = $groups->groups_for_hosts(\@hosts);

This method returns all the groups to which at least one of the given hosts
belongs.

=cut

sub groups_for_hosts {
  my ($invocant, $hosts) = @_;
  my $self = $invocant->_self;

  $hosts = [ $hosts ] unless ref $hosts;

  my $gh = Clone::clone $self->_group_hosts;

  my %seen;
  for my $host (@$hosts) {
    for my $group (keys %$gh) {
      if (List::MoreUtils::any { $_ eq $host } @{ $gh->{$group} }) {
        $seen{$group} = 1;
        delete $gh->{$group}; # we saw it once, no need to check it again
      }
    }
  }

  return sort keys %seen;
}

=head2 intersecting_groups_for_hosts

  my @groups = $groups->intersecting_groups_for_hosts($host);

  my @groups = $groups->intersecting_groups_for_hosts(\@hosts);

This method returns all the groups to which all one of the given hosts belong.

=cut

sub intersecting_groups_for_hosts {
  my ($invocant, $hosts) = @_;
  my $self = $invocant->_self;
  $hosts = [ $hosts ] unless ref $hosts;

  my $gh = Clone::clone $self->_group_hosts;

  for my $host (@$hosts) {
    GROUP: for my $group (keys %$gh) {
      unless (List::MoreUtils::any { $_ eq $host } @{ $gh->{$group} }) {
        delete $gh->{$group};
        next GROUP;
      }
    }
  }

  return sort keys %$gh;
}

=head2 hosts_for_groups

  my @hosts = $groups->hosts_for_groups($group);

  my @hosts = $groups->hosts_for_groups(\@groups);

This method returns all the hosts found in the union of all the given groups.

=cut

sub hosts_for_groups {
  my ($invocant, $groups) = @_;
  my $self = $invocant->_self;
  $groups = [ $groups ] if not ref $groups;

  my $gh = $self->_group_hosts;

  my %host;
  for my $group (@$groups) {
    unless (exists $gh->{ $group }) {
      warn "no such group: $group";
      next;
    }
    $host{$_}++ for @{ $gh->{$group} };
  }

  return sort keys %host;
}

=head2 hosts_for_intersecting_groups

  my @hosts = $groups->hosts_for_intersecting_groups(\@groups);

This method returns all the hosts found in the union of all the given groups.

=cut

sub hosts_for_intersecting_groups {
  my ($invocant, $groups) = @_;
  my $self = $invocant->_self;
  return $self->hosts_for_groups($groups) unless ref $groups;

  my $gh = $self->_group_hosts;

  my %host;
  for my $group (@$groups) {
    unless (exists $gh->{ $group }) {
      warn "no such group: $group";
      next;
    }
    $host{$_}++ for @{ $gh->{$group} };
  }

  return grep { $host{$_} == @$groups } sort keys %host;
}

=head2 all_groups

  my @groups = $groups->all_groups;

This returns a list of all the known groups.

=cut

sub all_groups {
  my ($invocant) = @_;
  my $self = $invocant->_self;
  return keys %{ $self->_group_hosts };
}

=head2 host

  my $host = $groups->host( $hostname );

=cut

sub host {
  my ($invocant, $hostname) = @_;
  my $self = $invocant->_self;

  $self->{host_class}->_new($hostname, $self);
}

1;
