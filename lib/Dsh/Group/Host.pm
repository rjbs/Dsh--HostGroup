use strict;
use warnings;
package Dsh::Group::Host;

use Sys::Hostname;

use vars qw/ %opsys $options /;

# Our groups, which map to uname.
$opsys{ debian  } = 'Linux';
$opsys{ solaris } = 'SunOS';
$opsys{ openbsd } = 'OpenBSD';

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

sub opsys {
  my ($self) = @_;

  my ($os_group) = grep { exists $opsys{ $_ } }
                   $self->_groups->groups_for_hosts($self->hostname);

  $os_group = $opsys{$os_group} if $os_group;

  return $os_group;
}

sub members {
  my ($self) = @_;

  return [ $self->_groups->groups_for_hosts($self->hostname) ];
}

sub loc {
  my ($self) = @_;
  my ($loc) = $self->_groups->locations_for_hosts($self->hostname);
  return $loc;
}

sub is_member {
  my ($self, @group_names) = @_;

  my $in_all = grep { $_ eq $self->hostname }
               $self->_groups->hosts_for_intersecting_groups(\@group_names);

  return $in_all ? 1 : 0;
}

1;
