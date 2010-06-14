use strict;
use warnings;
package Dsh::Groups;

=head1 NAME

Dsh::Groups - look up machines and groups

=head1 VERSION

version 1.000

=cut

our $VERSION = '1.000';

use Clone;
use List::MoreUtils;

=head1 METHODS

=cut

my $ROOT = $ENV{Dsh_HOSTGROUPS_ROOT} || '/etc/dsh/group/';

my %group_hosts;
sub _group_hosts {
  return \%group_hosts if keys %group_hosts;

  my @group_files = glob("$ROOT/*");

  GROUPFILE: for my $file (@group_files) {
    if (-l $file) {
      my $target = readlink $file;
      next GROUPFILE unless -e $target;
    }
    my ($group) = $file =~ m{([^/]+)\z};
    open my $fh, '<', $file or die "couldn't open group file for $group: $!";
    my @lines = grep { $_ !~ /^#/ } <$fh>;
    chomp @lines;
    $group_hosts{ $group } = \@lines;
  }

  return \%group_hosts;
}

=head2 groups_for_hosts

  my @groups = Dsh::Groups->groups_for_hosts($host);

  my @groups = Dsh::Groups->groups_for_hosts(\@hosts);

This method returns all the groups to which at least one of the given hosts
belongs.

=cut

sub groups_for_hosts {
  my ($class, $hosts) = @_;
  $hosts = [ $hosts ] unless ref $hosts;

  my $gh = Clone::clone $class->_group_hosts;

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

  my @groups = Dsh::Groups->intersecting_groups_for_hosts($host);

  my @groups = Dsh::Groups->intersecting_groups_for_hosts(\@hosts);

This method returns all the groups to which all one of the given hosts belong.

=cut

sub intersecting_groups_for_hosts {
  my ($class, $hosts) = @_;
  $hosts = [ $hosts ] unless ref $hosts;

  my $gh = Clone::clone $class->_group_hosts;

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

  my @hosts = Dsh::Groups->hosts_for_groups($group);

  my @hosts = Dsh::Groups->hosts_for_groups(\@groups);

This method returns all the hosts found in the union of all the given groups.

=cut

sub hosts_for_groups {
  my ($class, $groups) = @_;
  $groups = [ $groups ] if not ref $groups;

  my $gh = $class->_group_hosts;

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

  my @hosts = Dsh::Groups->hosts_for_intersecting_groups(\@groups);

This method returns all the hosts found in the union of all the given groups.

=cut

sub hosts_for_intersecting_groups {
  my ($class, $groups) = @_;
  return $class->hosts_for_groups($groups) unless ref $groups;

  my $gh = $class->_group_hosts;

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

  my @locations = Dsh::Groups->locations_for_hosts(\@hosts, \%arg);

Valid arguments are:

  trust_zone - choose zone's loc over machine's explicit loc; default: false

=cut

sub locations_for_hosts {
  my ($class, $hosts, $arg) = @_;
  $arg ||= {};

  my @groups = $class->groups_for_hosts($hosts);
  my @zones  = map { s/^zones-//; $_ } grep { /^zones-/ } @groups;

  if (@zones and $arg->{trust_zone}) {
    return $class->locations_for_hosts(\@zones, $arg);
  }

  my @locs;

  if (@locs = grep { /^loc-/ } @groups) {
    s/^loc-// for @locs;
  }

  if (@zones) {
    push @locs, $class->locations_for_hosts(\@zones);
  }

  return List::MoreUtils::uniq(@locs);
}

=head2 all_groups

  my @groups = Dsh::Groups->all_groups;

This returns a list of all the known groups.

=cut

sub all_groups {
  my ($class) = @_;
  return keys %{ $class->_group_hosts };
}

1;
