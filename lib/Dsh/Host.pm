package Dsh::Host;

use strict;
use warnings;

use Dsh::Groups;
use Sys::Hostname;

use vars qw/ %opsys $options /;

# Our groups, which map to uname.
$opsys{ debian  } = 'Linux';
$opsys{ solaris } = 'SunOS';
$opsys{ openbsd } = 'OpenBSD';

sub new {
  my ( $class, $arg_ref ) = @_;

  $options = {
    host    => $arg_ref->{ host } ||= hostname,
  };

  my $new_object = bless $options, $class;

  return $new_object;
}

sub host {
  my ( $self, $new_host ) = @_;

  if ( $new_host ) {
    $self->{ host } = $new_host;
  }

  return $self->{ host };
}

sub opsys {
  my $self = shift;

  my ($os_group) = grep { exists $opsys{ $_ } }
                   Dsh::Groups->groups_for_hosts($self->host);

  $os_group = $opsys{$os_group} if $os_group;

  if (!$os_group and $self->host eq hostname) {
    my $uname = `/bin/uname -s`;
    chomp $uname;
    $os_group = $uname;
  }

  return $os_group;
}

sub members {
  my $self = shift;

  return [ Dsh::Groups->groups_for_hosts($self->host) ];
}

sub loc {
  my ($self) = @_;
  my ($loc) = Dsh::Groups->locations_for_hosts($self->host);
  return $loc;
}

sub is_member {
  my ( $self, @groups ) = @_;

  my $in_all = grep { $_ eq $self->host }
               Dsh::Groups->hosts_for_intersecting_groups(\@groups);

  return $in_all ? 1 : 0;
}

1;
