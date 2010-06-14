#!perl
use strict;
use warnings;

use Test::More 0.88;
use Dsh::Group::Groups;
use Dsh::Group::Host;

my $hg;
my $tests = sub { 
  is_deeply(
    [ $hg->groups_for_hosts('quux') ],
    [ qw(loc-moon quake solaris) ],
    "quux groups",
  );

  is_deeply(
    [ $hg->intersecting_groups_for_hosts([ qw(bar quux) ]) ],
    [ qw(quake) ],
    "group intersections",
  );

  my $quux_groups = $hg->host('quux');
  is($quux_groups->opsys, 'SunOS', 'quux os is correct');
  is($quux_groups->location,   'moon',  'quux is on the moon');

  my $whingo_groups = $hg->host('whingo');
  is($whingo_groups->location, 'moon',  'found whingo on the moon, via zonehost');
};

{
  package DGGI;
  use base 'Dsh::Group::Groups';
  sub default_host_class { 'Dsh::Group::Host::ICG' }
}

{
  local $ENV{DSH_HOSTGROUPS_ROOT} = 't/hostgroups';
  $hg = 'DGGI';
  $tests -> ();
}

{
  $hg = DGGI->for_root('t/hostgroups');
  $tests -> ();
}

done_testing;
