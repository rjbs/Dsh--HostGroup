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

  my $quux = $hg->host('quux');
  is($quux->hostname, 'quux', 'quux is eponymous');
  is($quux->physical_host->hostname, 'quux', 'quux is its own physical host');
  is($quux->opsys, 'SunOS', 'quux os is correct');
  is($quux->location,   'moon',  'quux is on the moon');

  my $whingo = $hg->host('whingo');
  is($whingo->hostname, 'whingo', 'whingo is eponymous');
  is($whingo->physical_host->hostname, 'quux', 'whingo is hosted on quux quux');
  is($whingo->location, 'moon',  'found whingo on the moon, via zonehost');
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
