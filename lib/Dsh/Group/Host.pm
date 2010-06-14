use strict;
use warnings;
package Dsh::Group::Host;

sub _new {
  my ($class, $hostname, $groups) = @_;

  my $guts = {
    hostname => $hostname,
    groups   => $groups,
  };

  return bless $guts => $class;
}

sub hostname { $_[0]{hostname} }

sub _groups { $_[0]{groups} }

sub groups {
  my ($self) = @_;

  return [ $self->_groups->groups_for_hosts($self->hostname) ];
}

sub is_member_of {
  my ($self, @group_names) = @_;

  my $in_all = grep { $_ eq $self->hostname }
               $self->_groups->hosts_for_intersecting_groups(\@group_names);

  return $in_all ? 1 : 0;
}

1;
