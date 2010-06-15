use strict;
use warnings;
package Dsh::Group::Host::ICG;
use base 'Dsh::Group::Host';

=head1 NAME

Dsh::Group::Host::ICG - Implementations for Conventions in Group names

=cut

use vars qw/ %opsys $options /;

# Our groups, which map to uname.
$opsys{ debian  } = 'Linux';
$opsys{ solaris } = 'SunOS';
$opsys{ openbsd } = 'OpenBSD';

sub opsys {
  my ($self) = @_;

  my $host = $self->physical_host;

  my ($os_group) = grep { exists $opsys{ $_ } }
                   $self->_groups->groups_for_hosts($host->hostname);

  $os_group = $opsys{$os_group} if $os_group;

  return $os_group;
}

sub is_member {
  my ($self, @group_names) = @_;

  my $in_all = grep { $_ eq $self->hostname }
               $self->_groups->hosts_for_intersecting_groups(\@group_names);

  return $in_all ? 1 : 0;
}

sub physical_host {
  my ($self) = @_;

  my @zones = grep { m{^zones[/-]} } @{ $self->groups };
  return $self unless @zones;

  Carp::carp(sprintf "host %s is in multiple zone groups", $self->hostname)
    if @zones > 1;

  my ($name) = $zones[0] =~ m{^zones[/-](.+)$};
  $self->_groups->host($name);
}

sub location {
  my ($self) = @_;
  my $host = $self->physical_host;

  my @locs = grep { m{^loc[/-]} } @{ $host->groups };

  return unless @locs;

  Carp::carp(sprintf "host %s is in multiple loc groups", $self->hostname)
    if @locs > 1;

  my ($loc) = $locs[0] =~ m{^loc[/-](.+)$};

  return $loc;
}

1;
