use strict;
use warnings;
package Dsh::Group::Groups;

=head1 NAME

Dsh::Group::Groups - look up machines and groups

=head1 VERSION

version 1.000

=cut

our $VERSION = '1.000';

use Clone;
use List::MoreUtils;

=head1 METHODS

=cut

my %FOR_ROOT;

=head2 for_root

  my $groups = Dsh::Group::Groups->for_root( $dsh_groups_root );

If no root is supplied, the env var C<DSH_HOSTGROUPS_ROOT> is consulted.  If
that's not defined F</etc/dsh/group> is used.  Groups objects are cached.

=cut

sub for_root {
  my ($class, $root) = @_;
  $root ||= $ENV{DSH_HOSTGROUPS_ROOT} || '/etc/dsh/group/';
  return $FOR_ROOT{ $root } ||= $class->_new($root);
}

sub _new {
  my ($class, $root) = @_;
  return bless { root => $root } => $class;
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

  my @group_files = glob("$root/*");

  GROUPFILE: for my $file (@group_files) {
    if (-l $file) {
      my $target = readlink $file;
      next GROUPFILE unless -e $target;
    }
    my ($group) = $file =~ m{([^/]+)\z};
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

=head2 locations_for_hosts

  my @locations = $groups->locations_for_hosts(\@hosts, \%arg);

Valid arguments are:

  trust_zone - choose zone's loc over machine's explicit loc; default: false

=cut

sub locations_for_hosts {
  my ($invocant, $hosts, $arg) = @_;
  my $self = $invocant->_self;
  $arg ||= {};

  my @groups = $self->groups_for_hosts($hosts);
  my @zones  = map { s/^zones-//; $_ } grep { /^zones-/ } @groups;

  if (@zones and $arg->{trust_zone}) {
    return $self->locations_for_hosts(\@zones, $arg);
  }

  my @locs;

  if (@locs = grep { /^loc-/ } @groups) {
    s/^loc-// for @locs;
  }

  if (@zones) {
    push @locs, $self->locations_for_hosts(\@zones);
  }

  return List::MoreUtils::uniq(@locs);
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

  Dsh::Group::Host->_new($hostname, $self);
}

1;
