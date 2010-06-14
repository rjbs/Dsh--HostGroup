#!perl
use strict;
use warnings;

BEGIN { $ENV{ICG_HOSTGROUPS_ROOT} = 't/hostgroups'; }

use Test::More tests => 5;
use ICG::HostGroups;
use ICG::Systems::Groups;

my $hg = 'ICG::HostGroups';

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

my $quux_groups = ICG::Systems::Groups->new({ host => 'quux' });
is($quux_groups->opsys, 'SunOS', 'quux os is correct');
is($quux_groups->loc,   'moon',  'quux is on the moon');

my $whingo_groups = ICG::Systems::Groups->new({ host => 'whingo' });
is($whingo_groups->loc, 'moon',  'found whingo on the moon, via its zonehost');